import 'dart:async';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

enum AuthState { loading, unauthenticated, otpSent, authenticated }

class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? destination;

  const AuthResult({required this.success, this.errorMessage, this.destination});
}

class AuthService {
  final bool isTestMode;
  
  AuthState _state = AuthState.loading;
  String? _username;
  DateTime? _lastOtpSent;
  String? _destination;

  late final CognitoUserPool _userPool;
  CognitoUser? _cognitoUser;

  static const otpCooldownSeconds = 60;
  static const maxAttempts = 5;

  AuthService({this.isTestMode = false}) {
    if (!isTestMode) {
      _userPool = CognitoUserPool(Config.cognitoUserPoolId, Config.cognitoClientId);
    }
  }

  AuthState get state => _state;
  String? get destination => _destination;

  int get resendCooldownRemaining {
    if (_lastOtpSent == null) return 0;
    final elapsed = DateTime.now().difference(_lastOtpSent!).inSeconds;
    final remaining = otpCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  bool get canResendOtp => resendCooldownRemaining == 0;

  Future<void> initialize() async {
    if (isTestMode) {
      _state = AuthState.unauthenticated;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null && token.isNotEmpty) {
        _state = AuthState.authenticated;
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      _state = AuthState.unauthenticated;
    }
  }

  Future<AuthResult> signIn(String username) async {
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
        await _cognitoUser!.initiateAuth(AuthenticationDetails(username: username));
      } on CognitoUserCustomChallengeException {
        // Expected exception indicating OTP is sent
      } on CognitoClientException catch (e) {
        if (e.code == 'UserNotFoundException') {
          // Auto sign-up for new users
          await _userPool.signUp(username, 'MapVibeTempPwd123!');
          _cognitoUser = CognitoUser(username, _userPool);
          _cognitoUser!.setAuthenticationFlowType('CUSTOM_AUTH');
          try {
            await _cognitoUser!.initiateAuth(AuthenticationDetails(username: username));
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
      return AuthResult(success: false, errorMessage: 'Loi ket noi hoac Sdt khong hop le.');
    }
  }

  Future<AuthResult> verifyOtp(String code) async {
    if (_username == null) {
      return const AuthResult(success: false, errorMessage: 'No sign-in in progress');
    }

    if (isTestMode) {
      _state = AuthState.authenticated;
      return const AuthResult(success: true);
    }

    try {
      final session = await _cognitoUser!.sendCustomChallengeAnswer(code);
      if (session != null && session.isValid()) {
        _state = AuthState.authenticated;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', session.getAccessToken().getJwtToken() ?? '');
        
        return const AuthResult(success: true);
      } else {
        return const AuthResult(success: false, errorMessage: 'Ma xac thuc sai');
      }
    } catch (e) {
      return AuthResult(success: false, errorMessage: 'Ma xac thuc sai hoac loi ket noi.');
    }
  }

  Future<AuthResult> resendOtp() async {
    if (!canResendOtp) {
      return AuthResult(
        success: false,
        errorMessage: 'Vui long cho $resendCooldownRemaining giay truoc khi gui lai.',
      );
    }
    if (_username == null) {
      return const AuthResult(success: false, errorMessage: 'No sign-in in progress');
    }
    return await signIn(_username!);
  }

  Future<void> signOut() async {
    if (!isTestMode && _cognitoUser != null) {
      await _cognitoUser!.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
    }
    _state = AuthState.unauthenticated;
    _username = null;
    _session = null;
    _destination = null;
    _cognitoUser = null;
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
    return '${input.substring(0, input.length - 6)}***${input.substring(input.length - 3)}';
  }
  
  // ignore: unused_field
  String? _session;
}
