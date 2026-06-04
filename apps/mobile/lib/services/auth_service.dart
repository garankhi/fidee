import 'dart:async';
import 'dart:convert';

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

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
  String? _since;

  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get preferredUsername => _preferredUsername;
  String? get avatarUrl => _avatarUrl;
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
            final name = attr.getName();
            final value = attr.getValue() ?? '';
            if (name == 'given_name') {
              _firstName = value;
              if (value.isNotEmpty) hasName = true;
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

        // Fetch full profile details from PostgreSQL (createdAt, friendCount, etc.)
        await fetchProfileDetails();

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
    if (isTestMode) {
      _state = AuthState.authenticated;
      return const AuthResult(success: true);
    }

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: '255813663531-rd534l11ckmgrobpo4imj2kdnshpq3ap.apps.googleusercontent.com',
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
        final randomPassword = 'GoogleAuth_${const Uuid().v4().replaceAll('-', '')}';
        final attributes = [
          AttributeArg(name: 'email', value: _username),
          if (googleUser.displayName != null && googleUser.displayName!.isNotEmpty) ...[
            AttributeArg(name: 'given_name', value: googleUser.displayName),
            const AttributeArg(name: 'family_name', value: 'Google User'),
          ]
        ];
        await _userPool.signUp(_username!, randomPassword, userAttributes: attributes);
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
          _state = AuthState.authenticated;
          return const AuthResult(success: true);
        }

        return const AuthResult(
          success: false,
          errorMessage: 'Không khởi tạo được phiên đăng nhập',
        );
      } on CognitoUserCustomChallengeException catch (e) {
        if (e.challengeParameters != null &&
            e.challengeParameters['provider'] == 'google') {
          
          final challengeSession = await _cognitoUser!.sendCustomChallengeAnswer(
            idToken,
            {'provider': 'google'},
          );

          if (challengeSession != null && challengeSession.isValid()) {
            _state = AuthState.authenticated;

            try {
              final attributes = await _cognitoUser!.getUserAttributes();
              bool hasName = false;
              if (attributes != null) {
                for (var attr in attributes) {
                  if (attr.getName() == 'given_name' && (attr.getValue()?.isNotEmpty ?? false)) {
                    hasName = true;
                  }
                  if (attr.getName() == 'custom:tier') {
                    _tier = attr.getValue() == 'pro' ? UserTier.pro : UserTier.free;
                  }
                }
              }
              if (!hasName) {
                _state = AuthState.incompleteProfile;
              }
            } catch (_) {
              // fallback
            }

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
        debugPrint('DEBUG [AuthService]: Failed to clear storage: $storageError');
      }
    } finally {
      _state = AuthState.unauthenticated;
      _username = null;
      _cognitoUser = null;
      _destination = null;
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
        final String? displayName = data['displayName'] as String?;
        if (displayName != null) {
          final parts = displayName.split(' ');
          _firstName = parts.isNotEmpty ? parts.first : _firstName;
          _lastName = parts.length > 1 ? parts.skip(1).join(' ') : _lastName;
        }
        _preferredUsername = data['username'] as String? ?? _preferredUsername;
        _avatarUrl = data['avatarUrl'] as String? ?? _avatarUrl;
        if (data['plan'] == 'PRO') {
          _tier = UserTier.pro;
        } else {
          _tier = UserTier.free;
        }
        
        // Parse "since" year
        final createdAtStr = data['createdAt'] as String?;
        if (createdAtStr != null) {
          final dt = DateTime.parse(createdAtStr);
          _since = dt.year.toString();
        }
      }
    } catch (_) {
      // ignore
    }
  }

  Future<AuthResult> updateProfile({
    String? firstName,
    String? lastName,
    String? preferredUsername,
    String? avatarUrl,
  }) async {
    if (isTestMode) {
      if (firstName != null) _firstName = firstName;
      if (lastName != null) _lastName = lastName;
      if (preferredUsername != null) _preferredUsername = preferredUsername;
      if (avatarUrl != null) _avatarUrl = avatarUrl;
      return const AuthResult(success: true);
    }

    if (firstName != null || lastName != null || preferredUsername != null) {
      final currentFirstName = firstName ?? _firstName ?? '';
      final currentLastName = lastName ?? _lastName ?? '';
      final currentUsername = preferredUsername ?? _preferredUsername ?? '';

      return _patchProfileDetails(
        firstName: currentFirstName,
        lastName: currentLastName,
        username: currentUsername,
      );
    }

    try {
      if (_cognitoUser != null) {
        final attributes = <CognitoUserAttribute>[];
        if (firstName != null) {
          attributes.add(CognitoUserAttribute(name: 'given_name', value: firstName));
        }
        if (lastName != null) {
          attributes.add(CognitoUserAttribute(name: 'family_name', value: lastName));
        }
        if (preferredUsername != null) {
          attributes.add(CognitoUserAttribute(name: 'preferred_username', value: preferredUsername));
        }
        if (avatarUrl != null) {
          attributes.add(CognitoUserAttribute(name: 'picture', value: avatarUrl));
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
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'username': username.trim(),
        }),
      );

      final body = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final profile = body['profile'] as Map<String, dynamic>?;
        _firstName = firstName.trim();
        _lastName = lastName.trim();
        _preferredUsername = profile?['username'] as String? ?? username.trim().toLowerCase();
        _avatarUrl = profile?['avatarUrl'] as String? ?? _avatarUrl;

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

      final error = body['error'] as String?;
      return AuthResult(
        success: false,
        errorMessage: error ?? 'Cập nhật profile thất bại',
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
