import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../services/auth_service.dart';

part 'auth_providers.g.dart';

class AuthUiState {
  final AuthState authState;
  final UserTier tier;
  final String? destination;
  final int resendCooldownRemaining;
  final bool isSubmitting;
  final bool isVerifying;
  final String? errorMessage;

  const AuthUiState({
    required this.authState,
    this.tier = UserTier.free,
    this.destination,
    this.resendCooldownRemaining = 0,
    this.isSubmitting = false,
    this.isVerifying = false,
    this.errorMessage,
  });

  factory AuthUiState.fromService(
    AuthService service, {
    bool isSubmitting = false,
    bool isVerifying = false,
    String? errorMessage,
  }) {
    return AuthUiState(
      authState: service.state,
      tier: service.tier,
      destination: service.destination,
      resendCooldownRemaining: service.resendCooldownRemaining,
      isSubmitting: isSubmitting,
      isVerifying: isVerifying,
      errorMessage: errorMessage,
    );
  }

  AuthUiState copyWith({
    AuthState? authState,
    UserTier? tier,
    String? destination,
    int? resendCooldownRemaining,
    bool? isSubmitting,
    bool? isVerifying,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthUiState(
      authState: authState ?? this.authState,
      tier: tier ?? this.tier,
      destination: destination ?? this.destination,
      resendCooldownRemaining:
          resendCooldownRemaining ?? this.resendCooldownRemaining,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isVerifying: isVerifying ?? this.isVerifying,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

@Riverpod(keepAlive: true)
AuthService authService(AuthServiceRef ref) {
  return AuthService();
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<AuthUiState> build() async {
    final service = ref.read(authServiceProvider);
    await service.initialize();
    return AuthUiState.fromService(service);
  }

  Future<AuthResult> signIn(String email, String password) async {
    final current = _currentState();
    state = AsyncData(current.copyWith(isSubmitting: true, clearError: true));

    final service = ref.read(authServiceProvider);
    final result = await service.signIn(email, password);
    state = AsyncData(
      AuthUiState.fromService(
        service,
        errorMessage: result.success ? null : result.errorMessage,
      ),
    );
    return result;
  }

  Future<AuthResult> signUp(String email, String password) async {
    final current = _currentState();
    state = AsyncData(current.copyWith(isSubmitting: true, clearError: true));

    final service = ref.read(authServiceProvider);
    final result = await service.signUp(email, password);
    state = AsyncData(
      AuthUiState.fromService(
        service,
        errorMessage: result.success ? null : result.errorMessage,
      ),
    );
    return result;
  }

  Future<AuthResult> signInWithGoogle() async {
    final current = _currentState();
    state = AsyncData(current.copyWith(isSubmitting: true, clearError: true));

    final service = ref.read(authServiceProvider);
    final result = await service.signInWithGoogle();
    state = AsyncData(
      AuthUiState.fromService(
        service,
        errorMessage: result.success ? null : result.errorMessage,
      ),
    );
    return result;
  }

  Future<AuthResult> verifyOtp(String code) async {
    final current = _currentState();
    state = AsyncData(current.copyWith(isVerifying: true, clearError: true));

    final service = ref.read(authServiceProvider);
    final result = await service.verifyOtp(code);
    state = AsyncData(
      AuthUiState.fromService(
        service,
        errorMessage: result.success ? null : result.errorMessage,
      ),
    );
    return result;
  }

  Future<AuthResult> resendOtp() async {
    clearError();
    final service = ref.read(authServiceProvider);
    final result = await service.resendOtp();
    state = AsyncData(
      AuthUiState.fromService(
        service,
        errorMessage: result.success ? null : result.errorMessage,
      ),
    );
    return result;
  }

  Future<void> signOut() async {
    final service = ref.read(authServiceProvider);
    await service.signOut();
    state = AsyncData(AuthUiState.fromService(service));
  }

  void setError(String message) {
    state = AsyncData(_currentState().copyWith(errorMessage: message));
  }

  void clearError() {
    state = AsyncData(_currentState().copyWith(clearError: true));
  }

  AuthUiState _currentState() {
    return state.valueOrNull ??
        const AuthUiState(authState: AuthState.unauthenticated);
  }
}

