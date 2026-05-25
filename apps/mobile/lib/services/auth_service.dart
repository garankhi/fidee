import 'dart:async';
import 'dart:convert';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

// Persistent Cognito storage.
/// Stores Cognito tokens in platform secure storage so they survive app
/// restarts without plaintext prefs.
class SecureCognitoStorage extends CognitoStorage {
  static const _cognitoKeyPrefix = 'CognitoIdentityServiceProvider.';

  final Future<String?> Function(String key) _read;
  final Future<Map<String, String>> Function() _readAll;
  final Future<void> Function(String key, String value) _write;
  final Future<void> Function(String key) _delete;

  SecureCognitoStorage(FlutterSecureStorage storage)
    : this.custom(
        read: (key) => storage.read(key: key),
        readAll: storage.readAll,
        write: (key, value) => storage.write(key: key, value: value),
        delete: (key) => storage.delete(key: key),
      );

  SecureCognitoStorage.custom({
    required Future<String?> Function(String key) read,
    required Future<Map<String, String>> Function() readAll,
    required Future<void> Function(String key, String value) write,
    required Future<void> Function(String key) delete,
  }) : _read = read,
       _readAll = readAll,
       _write = write,
       _delete = delete;

  @override
  Future<dynamic> getItem(String key) async {
    final value = await _read(key);
    if (value == null) return null;

    try {
      return jsonDecode(value);
    } on FormatException {
      await _delete(key);
      return null;
    }
  }

  @override
  Future<dynamic> setItem(String key, value) async {
    await _write(key, jsonEncode(value));
    return value;
  }

  @override
  Future<dynamic> removeItem(String key) async {
    final oldValue = await getItem(key);
    await _delete(key);
    return oldValue;
  }

  @override
  Future<void> clear() async {
    final values = await _readAll();
    final cognitoKeys = values.keys.where(
      (key) => key.startsWith(_cognitoKeyPrefix),
    );
    for (final key in cognitoKeys) {
      await _delete(key);
    }
  }
}

// Auth state and result.
enum AuthState { loading, unauthenticated, otpSent, authenticated }

class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? destination;

  const AuthResult({
    required this.success,
    this.errorMessage,
    this.destination,
  });
}

// Auth service.
class AuthService {
  final bool isTestMode;

  AuthState _state = AuthState.loading;
  String? _username;
  DateTime? _lastOtpSent;
  String? _destination;

  late CognitoUserPool _userPool;
  CognitoUser? _cognitoUser;

  static const otpCooldownSeconds = 60;
  static const maxAttempts = 5;

  AuthService({this.isTestMode = false});

  AuthState get state => _state;
  String? get destination => _destination;

  int get resendCooldownRemaining {
    if (_lastOtpSent == null) return 0;
    final elapsed = DateTime.now().difference(_lastOtpSent!).inSeconds;
    final remaining = otpCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  bool get canResendOtp => resendCooldownRemaining == 0;

  /// Initialize: create persistent storage, restore session if available.
  Future<void> initialize() async {
    if (isTestMode) {
      _state = AuthState.unauthenticated;
      return;
    }

    SecureCognitoStorage? storage;

    try {
      storage = SecureCognitoStorage(const FlutterSecureStorage());

      _userPool = CognitoUserPool(
        Config.cognitoUserPoolId,
        Config.cognitoClientId,
        storage: storage,
      );

      // Try to restore cached user
      final user = await _userPool.getCurrentUser();

      if (user == null) {
        _state = AuthState.unauthenticated;
        return;
      }

      // Try to get valid session (auto-refreshes if needed)
      _cognitoUser = user;
      final session = await user.getSession();

      if (session != null && session.isValid()) {
        _username = user.getUsername();
        _state = AuthState.authenticated;
      } else {
        await user.signOut();
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      // Token invalid or network error; force re-login.
      await storage?.clear();
      _state = AuthState.unauthenticated;
      _username = null;
      _cognitoUser = null;
      _destination = null;
    }
  }

  Future<AuthResult> signIn(String rawUsername) async {
    // 1. Format the username
    String username = rawUsername.trim();
    final isEmail = username.contains('@');
    if (!isEmail) {
      // Auto format Vietnamese phone numbers if missing country code
      if (username.startsWith('0')) {
        username = '+84${username.substring(1)}';
      } else if (!username.startsWith('+')) {
        username = '+$username';
      }
    }

    _username = username;
    _destination = _maskDestination(username);

    if (isTestMode) {
      _state = AuthState.otpSent;
      _lastOtpSent = DateTime.now();
      return AuthResult(success: true, destination: _destination);
    }

    try {
      _cognitoUser = CognitoUser(username, _userPool);
      _cognitoUser!.setAuthenticationFlowType('CUSTOM_AUTH');

      try {
        await _cognitoUser!.initiateAuth(
          AuthenticationDetails(username: username),
        );
      } on CognitoUserCustomChallengeException {
        // Expected exception indicating OTP is sent
      } on CognitoClientException catch (e) {
        if (e.code == 'UserNotFoundException') {
          // Auto sign-up for new users with correct attributes
          final attributes = [
            AttributeArg(
              name: isEmail ? 'email' : 'phone_number',
              value: username,
            ),
          ];
          await _userPool.signUp(
            username,
            'MapVibeTempPwd123!',
            userAttributes: attributes,
          );

          _cognitoUser = CognitoUser(username, _userPool);
          _cognitoUser!.setAuthenticationFlowType('CUSTOM_AUTH');
          try {
            await _cognitoUser!.initiateAuth(
              AuthenticationDetails(username: username),
            );
          } on CognitoUserCustomChallengeException {
            // Expected
          }
        } else {
          rethrow;
        }
      }

      _state = AuthState.otpSent;
      _lastOtpSent = DateTime.now();
      return AuthResult(success: true, destination: _destination);
    } catch (e) {
      return const AuthResult(
        success: false,
        errorMessage: 'Loi ket noi hoac Sdt khong hop le.',
      );
    }
  }

  Future<AuthResult> verifyOtp(String code) async {
    if (_username == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'No sign-in in progress',
      );
    }

    if (isTestMode) {
      _state = AuthState.authenticated;
      return const AuthResult(success: true);
    }

    try {
      final session = await _cognitoUser!.sendCustomChallengeAnswer(code);
      if (session != null && session.isValid()) {
        _state = AuthState.authenticated;
        // Tokens are automatically cached to secure storage by the Cognito SDK.
        return const AuthResult(success: true);
      } else {
        return const AuthResult(
          success: false,
          errorMessage: 'Ma xac thuc sai',
        );
      }
    } catch (e) {
      return const AuthResult(
        success: false,
        errorMessage: 'Ma xac thuc sai hoac loi ket noi.',
      );
    }
  }

  Future<AuthResult> resendOtp() async {
    if (!canResendOtp) {
      return AuthResult(
        success: false,
        errorMessage:
            'Vui long cho $resendCooldownRemaining giay truoc khi gui lai.',
      );
    }
    if (_username == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'No sign-in in progress',
      );
    }
    return await signIn(_username!);
  }

  Future<void> signOut() async {
    if (!isTestMode && _cognitoUser != null) {
      // This clears tokens from SecureCognitoStorage
      await _cognitoUser!.signOut();
    }
    _state = AuthState.unauthenticated;
    _username = null;
    _cognitoUser = null;
    _destination = null;
  }

  String _maskDestination(String input) {
    if (input.contains('@')) {
      final parts = input.split('@');
      final local = parts[0];
      final domain = parts[1];
      if (local.length <= 2) return '$local***@$domain';
      return '${local.substring(0, 2)}***@$domain';
    }
    if (input.length <= 7) return '***';
    return '${input.substring(0, input.length - 6)}***'
        '${input.substring(input.length - 3)}';
  }
}
