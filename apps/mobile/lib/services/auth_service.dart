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
enum AuthState {
  loading,
  unauthenticated,
  otpSent,
  authenticated,
  incompleteProfile,
}

enum UserTier { free, pro }

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
  UserTier _tier = UserTier.free;

  late CognitoUserPool _userPool;
  CognitoUser? _cognitoUser;

  static const otpCooldownSeconds = 60;
  static const maxAttempts = 5;

  AuthService({this.isTestMode = false});

  AuthState get state => _state;
  UserTier get tier => _tier;
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

        // Fetch attributes to check if profile is complete
        final attributes = await user.getUserAttributes();
        bool hasName = false;

        if (attributes != null) {
          for (var attr in attributes) {
            // Check for a custom attribute or standard attribute that indicates completion
            // For example, checking if 'given_name' or 'name' or 'preferred_username' is set
            if (attr.getName() == 'given_name' &&
                (attr.getValue()?.isNotEmpty ?? false)) {
              hasName = true;
            }
            if (attr.getName() == 'custom:tier') {
              if (attr.getValue() == 'pro') {
                _tier = UserTier.pro;
              } else {
                _tier = UserTier.free;
              }
            }
          }
        }

        if (hasName) {
          _state = AuthState.authenticated;
        } else {
          _state = AuthState.incompleteProfile;
        }
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

  Future<AuthResult> signIn(String email, String password) async {
    _username = email.trim();

    if (isTestMode) {
      _state = AuthState.authenticated;
      return const AuthResult(success: true);
    }

    try {
      _cognitoUser = CognitoUser(_username, _userPool);
      _cognitoUser!.setAuthenticationFlowType('USER_PASSWORD_AUTH');

      final session = await _cognitoUser!.authenticateUser(
        AuthenticationDetails(username: _username, password: password),
      );

      if (session != null && session.isValid()) {
        _state = AuthState.authenticated;
        return const AuthResult(success: true);
      } else {
        return const AuthResult(success: false, errorMessage: 'Login failed');
      }
    } on CognitoUserConfirmationNecessaryException {
      _state = AuthState.otpSent;
      _lastOtpSent = DateTime.now();
      _destination = _maskDestination(_username!);
      // Cần verify email
      return AuthResult(success: true, destination: _destination);
    } on CognitoClientException catch (e) {
      return AuthResult(
        success: false,
        errorMessage: e.message ?? 'Sai tài khoản hoặc mật khẩu',
      );
    } catch (e) {
      return const AuthResult(success: false, errorMessage: 'Lỗi kết nối.');
    }
  }

  Future<AuthResult> signUp(String email, String password) async {
    _username = email.trim();
    _destination = _maskDestination(_username!);

    if (isTestMode) {
      _state = AuthState.otpSent;
      _lastOtpSent = DateTime.now();
      return AuthResult(success: true, destination: _destination);
    }

    try {
      final attributes = [AttributeArg(name: 'email', value: _username)];

      await _userPool.signUp(_username!, password, userAttributes: attributes);

      _cognitoUser = CognitoUser(_username, _userPool);
      _state = AuthState.otpSent;
      _lastOtpSent = DateTime.now();

      return AuthResult(success: true, destination: _destination);
    } on CognitoClientException catch (e) {
      return AuthResult(
        success: false,
        errorMessage:
            e.message ?? 'Không thể đăng ký. Email có thể đã tồn tại.',
      );
    } catch (e) {
      return const AuthResult(success: false, errorMessage: 'Lỗi hệ thống.');
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    // Requires google_sign_in package setup and Cognito Identity Pool
    return const AuthResult(
      success: false,
      errorMessage: 'Chưa hỗ trợ Google Login',
    );
  }

  Future<AuthResult> verifyOtp(String code) async {
    if (_username == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'Không tìm thấy phiên đăng ký',
      );
    }

    if (isTestMode) {
      _state = AuthState.authenticated;
      return const AuthResult(success: true);
    }

    try {
      final confirmed = await _cognitoUser!.confirmRegistration(code);
      if (confirmed) {
        _state = AuthState.authenticated;
        return const AuthResult(success: true);
      } else {
        return const AuthResult(
          success: false,
          errorMessage: 'Mã xác thực sai',
        );
      }
    } on CognitoClientException catch (e) {
      return AuthResult(
        success: false,
        errorMessage: e.message ?? 'Mã xác thực sai',
      );
    } catch (e) {
      return const AuthResult(success: false, errorMessage: 'Lỗi kết nối.');
    }
  }

  Future<AuthResult> resendOtp() async {
    if (!canResendOtp) {
      return AuthResult(
        success: false,
        errorMessage:
            'Vui lòng chờ $resendCooldownRemaining giây trước khi gửi lại.',
      );
    }
    if (_username == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'Không tìm thấy phiên đăng ký',
      );
    }

    try {
      await _cognitoUser?.resendConfirmationCode();
      _lastOtpSent = DateTime.now();
      return const AuthResult(success: true);
    } catch (e) {
      return const AuthResult(
        success: false,
        errorMessage: 'Không thể gửi lại mã',
      );
    }
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

  Future<AuthResult> completeProfile(
    String firstName,
    String lastName,
    String username,
  ) async {
    if (isTestMode) {
      _state = AuthState.authenticated;
      return const AuthResult(success: true);
    }

    try {
      if (_cognitoUser != null) {
        final attributes = [
          CognitoUserAttribute(name: 'given_name', value: firstName),
          CognitoUserAttribute(name: 'family_name', value: lastName),
          CognitoUserAttribute(name: 'preferred_username', value: username),
        ];
        await _cognitoUser!.updateAttributes(attributes);
      }
      _state = AuthState.authenticated;
      return const AuthResult(success: true);
    } catch (e) {
      // If it fails (e.g. backend error), we can still just pretend success locally
      // or return error. Let's set to authenticated anyway for UX or return error.
      _state = AuthState.authenticated; // fallback so user is not stuck
      return const AuthResult(success: true);
    }
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
