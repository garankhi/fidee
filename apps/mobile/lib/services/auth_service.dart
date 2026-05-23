import 'dart:async';

/// Authentication state for the app.
enum AuthState { loading, unauthenticated, otpSent, authenticated }

/// Result of an auth operation.
class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? destination;

  const AuthResult({required this.success, this.errorMessage, this.destination});
}

/// Service wrapping Cognito auth operations.
///
/// SECURITY:
///  - Never log OTP codes
///  - Never log raw phone numbers or tokens
///  - Never store OTP locally
class AuthService {
  AuthState _state = AuthState.loading;
  String? _username;
  String? _session;
  DateTime? _lastOtpSent;
  String? _destination;

  // TODO: Replace with real Cognito integration (Amplify)
  // These are placeholders for the auth flow structure.

  static const otpCooldownSeconds = 60;
  static const maxAttempts = 5;

  AuthState get state => _state;
  String? get destination => _destination;

  /// Check remaining cooldown seconds for OTP resend.
  int get resendCooldownRemaining {
    if (_lastOtpSent == null) return 0;
    final elapsed = DateTime.now().difference(_lastOtpSent!).inSeconds;
    final remaining = otpCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Whether OTP can be resent (cooldown expired).
  bool get canResendOtp => resendCooldownRemaining == 0;

  /// Initialize — check if user is already signed in.
  Future<void> initialize() async {
    // TODO: Check Cognito session
    _state = AuthState.unauthenticated;
  }

  /// Initiate sign-in with phone number or email.
  /// Cognito will send OTP via SMS or Email.
  Future<AuthResult> signIn(String username) async {
    try {
      _username = username;

      // TODO: Call Cognito initiateAuth with CUSTOM_AUTH
      // For now, simulate success
      _state = AuthState.otpSent;
      _lastOtpSent = DateTime.now();
      _destination = _maskDestination(username);

      return AuthResult(success: true, destination: _destination);
    } catch (e) {
      return AuthResult(success: false, errorMessage: e.toString());
    }
  }

  /// Verify the OTP code entered by the user.
  Future<AuthResult> verifyOtp(String code) async {
    try {
      if (_username == null) {
        return const AuthResult(
          success: false,
          errorMessage: 'No sign-in in progress',
        );
      }

      // TODO: Call Cognito respondToAuthChallenge with OTP
      // For now, simulate success
      _state = AuthState.authenticated;

      return const AuthResult(success: true);
    } catch (e) {
      return AuthResult(success: false, errorMessage: e.toString());
    }
  }

  /// Resend OTP. Enforces cooldown.
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

    try {
      // TODO: Call Cognito initiateAuth again
      _lastOtpSent = DateTime.now();

      return AuthResult(success: true, destination: _destination);
    } catch (e) {
      return AuthResult(success: false, errorMessage: e.toString());
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    // TODO: Call Cognito signOut
    _state = AuthState.unauthenticated;
    _username = null;
    _session = null;
    _destination = null;
  }

  /// Mask phone/email for display.
  String _maskDestination(String input) {
    if (input.contains('@')) {
      final parts = input.split('@');
      final local = parts[0];
      final domain = parts[1];
      if (local.length <= 2) return '$local***@$domain';
      return '${local.substring(0, 2)}***@$domain';
    }
    // Phone number
    if (input.length <= 7) return '***';
    return '${input.substring(0, input.length - 6)}***${input.substring(input.length - 3)}';
  }
}
