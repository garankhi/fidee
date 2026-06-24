import 'dart:async';
import 'dart:convert';

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config.dart';
import 'profile_details.dart';

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
        readAll: () => storage.readAll(),
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

class UsernameAvailabilityResult {
  final bool success;
  final bool available;
  final String? normalizedUsername;
  final String? errorMessage;

  const UsernameAvailabilityResult({
    required this.success,
    required this.available,
    this.normalizedUsername,
    this.errorMessage,
  });
}

Map<String, dynamic> decodeResponseObject(String responseBody) {
  if (responseBody.trim().isEmpty) {
    return <String, dynamic>{};
  }

  try {
    final decoded = jsonDecode(responseBody);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

@visibleForTesting
String profileUpdateErrorMessage(int statusCode, String responseBody) {
  final prefix = 'Cập nhật profile thất bại (HTTP $statusCode)';
  final trimmedBody = responseBody.trim();
  if (trimmedBody.isEmpty) {
    return prefix;
  }

  try {
    final decoded = jsonDecode(trimmedBody);
    if (decoded is Map<String, dynamic>) {
      final serverMessage =
          decoded['error'] as String? ?? decoded['message'] as String?;
      final code = decoded['code'] as String?;
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        return code == null || code.trim().isEmpty
            ? '$prefix: $serverMessage'
            : '$prefix: $serverMessage [$code]';
      }
      if (code != null && code.trim().isNotEmpty) {
        return '$prefix: $code';
      }
    }
  } catch (_) {
    // Fall through to raw body below.
  }

  return '$prefix: $trimmedBody';
}

// Auth service.
class AuthService {
  final bool isTestMode;

  AuthState _state = AuthState.loading;
  String? _username;
  DateTime? _lastOtpSent;
  String? _destination;
  UserTier _tier = UserTier.free;

  String? _firstName;
  String? _lastName;
  String? _preferredUsername;
  String? _avatarUrl;
  String? _bio;
  String? _since;
  String? _pendingSignUpEmail;
  String? _pendingSignUpPassword;

  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get preferredUsername => _preferredUsername;
  String? get avatarUrl => _avatarUrl;
  String? get bio => _bio;
  String? get since => _since;

  late CognitoUserPool _userPool;
  CognitoUser? _cognitoUser;

  static const otpCooldownSeconds = 60;
  static const maxAttempts = 5;

  AuthService({this.isTestMode = false});

  AuthState get state => _state;
  UserTier get tier => _tier;
  String? get destination => _destination;

  String? get username => _username;

  Future<String?> getToken() async {
    if (_cognitoUser == null) return null;
    try {
      final session = await _cognitoUser!.getSession();
      return session?.getIdToken().getJwtToken();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getCurrentUserSub() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;
      return payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  int get resendCooldownRemaining {
    if (_lastOtpSent == null) return 0;
    final elapsed = DateTime.now().difference(_lastOtpSent!).inSeconds;
    final remaining = otpCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  bool get canResendOtp => resendCooldownRemaining == 0;

  void _resetProfileDetails() {
    _tier = UserTier.free;
    _firstName = null;
    _lastName = null;
    _preferredUsername = null;
    _avatarUrl = null;
    _bio = null;
    _since = null;
  }

  void _clearPendingSignUpCredentials() {
    _pendingSignUpEmail = null;
    _pendingSignUpPassword = null;
  }

  void _applyProfileDetails(ProfileDetails details) {
    _firstName = details.firstName;
    _lastName = details.lastName;
    _preferredUsername = details.preferredUsername;
    _avatarUrl = details.avatarUrl;
    _bio = details.bio;
    _tier = details.tier;
    _since = details.since;
  }

  @visibleForTesting
  Future<void> applyProfileDetailsForTesting(Map<String, dynamic> data) async {
    _applyProfileDetails(ProfileDetails.fromJson(data));
  }

  @visibleForTesting
  bool get hasCompleteProfileForTesting => _hasCompleteProfile();

  bool _hasCompleteProfile() {
    final firstName = _firstName?.trim() ?? '';
    final lastName = _lastName?.trim() ?? '';
    final username = _preferredUsername?.trim() ?? '';

    return firstName.isNotEmpty &&
        lastName.isNotEmpty &&
        username.isNotEmpty &&
        firstName.toLowerCase() != 'user' &&
        !firstName.contains('@');
  }

  Future<bool> _hydrateAuthenticatedProfile() async {
    _resetProfileDetails();

    if (_cognitoUser != null) {
      final attributes = await _cognitoUser!.getUserAttributes();
      if (attributes != null) {
        for (final attr in attributes) {
          final name = attr.getName();
          final value = attr.getValue() ?? '';
          if (name == 'given_name') {
            _firstName = value;
          } else if (name == 'family_name') {
            _lastName = value;
          } else if (name == 'preferred_username') {
            _preferredUsername = value;
          } else if (name == 'picture') {
            _avatarUrl = value;
          } else if (name == 'custom:tier') {
            _tier = value == 'pro' ? UserTier.pro : UserTier.free;
          }
        }
      }
    }

    await fetchProfileDetails();
    return _hasCompleteProfile();
  }

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
        _resetProfileDetails();
        _state = AuthState.unauthenticated;
        return;
      }

      // Try to get valid session (auto-refreshes if needed)
      _cognitoUser = user;
      final session = await user.getSession();

      if (session != null && session.isValid()) {
        _username = user.getUsername();
        final hasName = await _hydrateAuthenticatedProfile();
        _state = hasName
            ? AuthState.authenticated
            : AuthState.incompleteProfile;
      } else {
        await user.signOut();
        _resetProfileDetails();
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      // Token invalid or network error; force re-login.
      await storage?.clear();
      _resetProfileDetails();
      _state = AuthState.unauthenticated;
      _username = null;
      _cognitoUser = null;
      _destination = null;
    }
  }

  Future<AuthResult> signIn(String email, String password) async {
    _resetProfileDetails();
    _clearPendingSignUpCredentials();
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
        _username = _cognitoUser?.getUsername() ?? _username;
        final hasName = await _hydrateAuthenticatedProfile();
        _state = hasName
            ? AuthState.authenticated
            : AuthState.incompleteProfile;
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
    _resetProfileDetails();
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
      _pendingSignUpEmail = _username;
      _pendingSignUpPassword = password;

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
    _resetProfileDetails();

    if (isTestMode) {
      _state = AuthState.authenticated;
      return const AuthResult(success: true);
    }

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '255813663531-rd534l11ckmgrobpo4imj2kdnshpq3ap.apps.googleusercontent.com',
      );

      final googleUser = await GoogleSignIn.instance.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String email = googleUser.email;

      if (idToken == null || idToken.isEmpty) {
        return const AuthResult(
          success: false,
          errorMessage: 'Không lấy được thông tin xác thực từ Google',
        );
      }

      _username = email.trim();
      _cognitoUser = CognitoUser(_username, _userPool);
      _cognitoUser!.setAuthenticationFlowType('CUSTOM_AUTH');

      try {
        final randomPassword =
            'GoogleAuth_${const Uuid().v4().replaceAll('-', '')}';
        final attributes = [
          AttributeArg(name: 'email', value: _username),
          if (googleUser.displayName != null &&
              googleUser.displayName!.isNotEmpty) ...[
            AttributeArg(name: 'given_name', value: googleUser.displayName),
            const AttributeArg(name: 'family_name', value: 'Google User'),
          ],
        ];
        await _userPool.signUp(
          _username!,
          randomPassword,
          userAttributes: attributes,
          clientMetadata: const {'provider': 'google'},
        );
      } on CognitoClientException catch (e) {
        if (e.code != 'UsernameExistsException') {
          return AuthResult(
            success: false,
            errorMessage: e.message ?? 'Đăng ký tài khoản Google thất bại',
          );
        }
      } catch (e) {
        // ignore other errors
      }

      try {
        final session = await _cognitoUser!.initiateAuth(
          AuthenticationDetails(
            authParameters: [
              AttributeArg(name: 'USERNAME', value: _username),
              const AttributeArg(name: 'provider', value: 'google'),
            ],
            validationData: const {'provider': 'google'},
          ),
        );

        if (session != null && session.isValid()) {
          final hasName = await _hydrateAuthenticatedProfile();
          _state = hasName
              ? AuthState.authenticated
              : AuthState.incompleteProfile;
          return const AuthResult(success: true);
        }

        return const AuthResult(
          success: false,
          errorMessage: 'Không khởi tạo được phiên đăng nhập',
        );
      } on CognitoUserCustomChallengeException catch (e) {
        if (e.challengeParameters != null &&
            e.challengeParameters['provider'] == 'google') {
          final challengeSession = await _cognitoUser!
              .sendCustomChallengeAnswer(idToken, {'provider': 'google'});

          if (challengeSession != null && challengeSession.isValid()) {
            final hasName = await _hydrateAuthenticatedProfile();
            _state = hasName
                ? AuthState.authenticated
                : AuthState.incompleteProfile;
            return const AuthResult(success: true);
          } else {
            return const AuthResult(
              success: false,
              errorMessage: 'Xác thực Google ID Token thất bại',
            );
          }
        } else {
          return const AuthResult(
            success: false,
            errorMessage: 'Quy trình xác thực Cognito không hợp lệ',
          );
        }
      }
    } on CognitoClientException catch (e) {
      return AuthResult(
        success: false,
        errorMessage: e.message ?? 'Lỗi kết nối đến dịch vụ AWS Cognito',
      );
    } catch (e) {
      debugPrint('DEBUG [AuthService] Google login error: $e');
      return const AuthResult(
        success: false,
        errorMessage: 'Lỗi hệ thống khi đăng nhập bằng Google',
      );
    }
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
        final email = _pendingSignUpEmail ?? _username;
        final password = _pendingSignUpPassword;
        if (email == null || password == null || password.isEmpty) {
          _state = AuthState.incompleteProfile;
          return const AuthResult(success: true);
        }

        _cognitoUser = CognitoUser(email, _userPool);
        _cognitoUser!.setAuthenticationFlowType('USER_PASSWORD_AUTH');
        final session = await _cognitoUser!.authenticateUser(
          AuthenticationDetails(username: email, password: password),
        );

        if (session == null || !session.isValid()) {
          return const AuthResult(
            success: false,
            errorMessage:
                'Xác thực email thành công nhưng chưa đăng nhập được. Vui lòng đăng nhập lại.',
          );
        }

        _username = _cognitoUser?.getUsername() ?? email;
        _clearPendingSignUpCredentials();
        final hasName = await _hydrateAuthenticatedProfile();
        _state = hasName
            ? AuthState.authenticated
            : AuthState.incompleteProfile;
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
    try {
      if (!isTestMode && _cognitoUser != null) {
        // This clears tokens from SecureCognitoStorage
        await _cognitoUser!.signOut();
      }
    } catch (e) {
      debugPrint('DEBUG [AuthService]: Remote signOut failed: $e');
      try {
        await _userPool.storage.clear();
      } catch (storageError) {
        debugPrint(
          'DEBUG [AuthService]: Failed to clear storage: $storageError',
        );
      }
    } finally {
      _resetProfileDetails();
      _state = AuthState.unauthenticated;
      _username = null;
      _cognitoUser = null;
      _destination = null;
      _clearPendingSignUpCredentials();
    }
  }

  Future<AuthResult> deleteAccount() async {
    if (isTestMode) {
      _resetProfileDetails();
      _state = AuthState.unauthenticated;
      _username = null;
      _cognitoUser = null;
      _destination = null;
      return const AuthResult(success: true);
    }

    final token = await getToken();
    final userId = await getCurrentUserSub();
    if (token == null || userId == null || userId.isEmpty) {
      return const AuthResult(
        success: false,
        errorMessage: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    try {
      final response = await http.delete(
        Uri.parse('${Config.apiBaseUrl}/users/$userId'),
        headers: {'Authorization': token},
      );
      final body = decodeResponseObject(response.body);

      if (response.statusCode == 200) {
        try {
          await _userPool.storage.clear();
        } catch (_) {
          // Ignore local storage cleanup failures after the server accepted deletion.
        }
        _resetProfileDetails();
        _state = AuthState.unauthenticated;
        _username = null;
        _cognitoUser = null;
        _destination = null;
        return const AuthResult(success: true);
      }

      final error = body['error'] as String?;
      return AuthResult(
        success: false,
        errorMessage: error ?? 'Không thể xóa tài khoản. Vui lòng thử lại.',
      );
    } catch (_) {
      return const AuthResult(
        success: false,
        errorMessage: 'Lỗi kết nối. Vui lòng thử lại.',
      );
    }
  }

  Future<AuthResult> completeProfile(
    String firstName,
    String lastName,
    String username,
  ) async {
    if (isTestMode) {
      _firstName = firstName;
      _lastName = lastName;
      _preferredUsername = username;
      _state = AuthState.authenticated;
      return const AuthResult(success: true);
    }

    final result = await _patchProfileDetails(
      firstName: firstName,
      lastName: lastName,
      username: username,
    );

    if (result.success) {
      _state = AuthState.authenticated;
    }

    return result;
  }

  Future<void> fetchProfileDetails() async {
    final token = await getToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/profile'),
        headers: {'Authorization': token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _applyProfileDetails(ProfileDetails.fromJson(data));
      }
    } catch (_) {
      // ignore
    }
  }

  Future<UsernameAvailabilityResult> checkUsernameAvailability(
    String username,
  ) async {
    final normalizedUsername = username.trim().toLowerCase();

    if (isTestMode) {
      return UsernameAvailabilityResult(
        success: true,
        available: true,
        normalizedUsername: normalizedUsername,
      );
    }

    final token = await getToken();
    if (token == null) {
      return const UsernameAvailabilityResult(
        success: false,
        available: false,
        errorMessage: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    try {
      final uri = Uri.parse(
        '${Config.apiBaseUrl}/profile/username-availability',
      ).replace(queryParameters: {'username': normalizedUsername});
      final response = await http.get(uri, headers: {'Authorization': token});
      final body = decodeResponseObject(response.body);

      if (response.statusCode == 200) {
        final available = body['available'] == true;
        return UsernameAvailabilityResult(
          success: true,
          available: available,
          normalizedUsername: body['username'] as String? ?? normalizedUsername,
          errorMessage: available ? null : 'Username đã được sử dụng',
        );
      }

      final code = body['code'] as String?;
      if (response.statusCode == 400 && code == 'VALIDATION_ERROR') {
        return const UsernameAvailabilityResult(
          success: false,
          available: false,
          errorMessage: 'Username không hợp lệ',
        );
      }

      final error = body['error'] as String?;
      return UsernameAvailabilityResult(
        success: false,
        available: false,
        errorMessage:
            error ?? 'Không kiểm tra được username. Vui lòng thử lại.',
      );
    } catch (_) {
      return const UsernameAvailabilityResult(
        success: false,
        available: false,
        errorMessage: 'Không kiểm tra được username. Vui lòng thử lại.',
      );
    }
  }

  Future<AuthResult> updateProfile({
    String? firstName,
    String? lastName,
    String? preferredUsername,
    String? avatarUrl,
    String? bio,
  }) async {
    if (isTestMode) {
      if (firstName != null) _firstName = firstName;
      if (lastName != null) _lastName = lastName;
      if (preferredUsername != null) _preferredUsername = preferredUsername;
      if (avatarUrl != null) _avatarUrl = avatarUrl;
      if (bio != null) _bio = bio;
      return const AuthResult(success: true);
    }

    if (firstName != null ||
        lastName != null ||
        preferredUsername != null ||
        bio != null) {
      final currentFirstName = firstName ?? _firstName ?? '';
      final currentLastName = lastName ?? _lastName ?? '';
      final currentUsername = preferredUsername ?? _preferredUsername ?? '';

      return _patchProfileDetails(
        firstName: currentFirstName,
        lastName: currentLastName,
        username: currentUsername,
        bio: bio ?? _bio ?? '',
      );
    }

    try {
      if (_cognitoUser != null) {
        final attributes = <CognitoUserAttribute>[];
        if (firstName != null) {
          attributes.add(
            CognitoUserAttribute(name: 'given_name', value: firstName),
          );
        }
        if (lastName != null) {
          attributes.add(
            CognitoUserAttribute(name: 'family_name', value: lastName),
          );
        }
        if (preferredUsername != null) {
          attributes.add(
            CognitoUserAttribute(
              name: 'preferred_username',
              value: preferredUsername,
            ),
          );
        }
        if (avatarUrl != null) {
          attributes.add(
            CognitoUserAttribute(name: 'picture', value: avatarUrl),
          );
        }

        if (attributes.isNotEmpty) {
          await _cognitoUser!.updateAttributes(attributes);
        }

        await fetchProfileDetails();

        if (firstName != null) _firstName = firstName;
        if (lastName != null) _lastName = lastName;
        if (preferredUsername != null) _preferredUsername = preferredUsername;
        if (avatarUrl != null) _avatarUrl = avatarUrl;
      }
      return const AuthResult(success: true);
    } catch (e) {
      return AuthResult(success: false, errorMessage: e.toString());
    }
  }

  Future<AuthResult> _patchProfileDetails({
    required String firstName,
    required String lastName,
    required String username,
    String bio = '',
  }) async {
    final token = await getToken();
    if (token == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    try {
      final response = await http.patch(
        Uri.parse('${Config.apiBaseUrl}/profile'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'username': username.trim(),
          'bio': bio.trim(),
        }),
      );

      final body = decodeResponseObject(response.body);

      if (response.statusCode == 200) {
        final profile = body['profile'] as Map<String, dynamic>?;
        _firstName = firstName.trim();
        _lastName = lastName.trim();
        _preferredUsername =
            profile?['username'] as String? ?? username.trim().toLowerCase();
        _avatarUrl = profile?['avatarUrl'] as String? ?? _avatarUrl;
        _bio = profile?['bio'] as String? ?? bio.trim();

        final plan = profile?['plan'] as String?;
        _tier = plan == 'PRO' ? UserTier.pro : UserTier.free;

        final createdAt = profile?['createdAt'] as String?;
        if (createdAt != null) {
          _since = DateTime.parse(createdAt).year.toString();
        }

        return const AuthResult(success: true);
      }

      final code = body['code'] as String?;
      if (response.statusCode == 409 && code == 'USERNAME_TAKEN') {
        return const AuthResult(
          success: false,
          errorMessage: 'Username đã được sử dụng',
        );
      }
      return AuthResult(
        success: false,
        errorMessage: profileUpdateErrorMessage(
          response.statusCode,
          response.body,
        ),
      );
    } catch (_) {
      return const AuthResult(
        success: false,
        errorMessage: 'Lỗi kết nối. Vui lòng thử lại.',
      );
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
