import 'package:fidee_mobile/features/auth/auth_providers.dart';
import 'package:fidee_mobile/features/auth/login_page.dart';
import 'package:fidee_mobile/main.dart';
import 'package:fidee_mobile/screens/home_screen.dart';
import 'package:fidee_mobile/screens/otp_screen.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget withAuthScope({
    required AuthService authService,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(authService)],
      child: child,
    );
  }

  group('FideeApp', () {
    testWidgets('initializes unauthenticated and shows login page', (
      WidgetTester tester,
    ) async {
      final authService = AuthService(isTestMode: true);

      await tester.pumpWidget(
        withAuthScope(authService: authService, child: const FideeApp()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });
  });

  group('LoginPage', () {
    testWidgets('renders login controls', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);

      await tester.pumpWidget(
        withAuthScope(
          authService: authService,
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('Email or Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('validates empty input', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);

      await tester.pumpWidget(
        withAuthScope(
          authService: authService,
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(
        find.text('Vui lòng nhập số điện thoại hoặc email'),
        findsOneWidget,
      );
    });

    testWidgets('toggles password visibility', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);

      await tester.pumpWidget(
        withAuthScope(
          authService: authService,
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('successful sign in navigates to OTP screen', (
      WidgetTester tester,
    ) async {
      final authService = AuthService(isTestMode: true);

      await tester.pumpWidget(
        withAuthScope(
          authService: authService,
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.byType(OtpScreen), findsOneWidget);
    });
  });

  group('OtpScreen', () {
    testWidgets('renders 6 OTP input fields', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);
      await authService.initialize();
      await authService.signIn('+84912345678');

      await tester.pumpWidget(
        withAuthScope(
          authService: authService,
          child: const MaterialApp(home: OtpScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Xac nhan'), findsOneWidget);
    });

    testWidgets('shows cooldown timer', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);
      await authService.initialize();
      await authService.signIn('+84912345678');

      await tester.pumpWidget(
        withAuthScope(
          authService: authService,
          child: const MaterialApp(home: OtpScreen()),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Gui lai ma sau'), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    testWidgets('renders map and UI elements', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);

      await tester.pumpWidget(
        withAuthScope(
          authService: authService,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('AuthService', () {
    test('initial state is loading', () {
      final service = AuthService(isTestMode: true);
      expect(service.state, AuthState.loading);
    });

    test('state is unauthenticated after init', () async {
      final service = AuthService(isTestMode: true);
      await service.initialize();
      expect(service.state, AuthState.unauthenticated);
    });

    test('sign in changes state to otpSent', () async {
      final service = AuthService(isTestMode: true);
      await service.initialize();
      final result = await service.signIn('+84912345678');
      expect(result.success, true);
      expect(service.state, AuthState.otpSent);
    });

    test('resend blocked during cooldown', () async {
      final service = AuthService(isTestMode: true);
      await service.initialize();
      await service.signIn('+84912345678');
      final result = await service.resendOtp();
      expect(result.success, false);
    });

    test('sign out resets state', () async {
      final service = AuthService(isTestMode: true);
      await service.initialize();
      await service.signIn('+84912345678');
      await service.signOut();
      expect(service.state, AuthState.unauthenticated);
    });
  });

  group('SecureCognitoStorage', () {
    late Map<String, String> values;
    late SecureCognitoStorage storage;

    setUp(() {
      values = <String, String>{};
      storage = SecureCognitoStorage.custom(
        read: (key) async => values[key],
        readAll: () async => Map<String, String>.from(values),
        write: (key, value) async {
          values[key] = value;
        },
        delete: (key) async {
          values.remove(key);
        },
      );
    });

    test('stores Cognito values as JSON in secure storage adapter', () async {
      await storage.setItem(
        'CognitoIdentityServiceProvider.client.user.refreshToken',
        'refresh-token',
      );

      expect(
        await storage.getItem(
          'CognitoIdentityServiceProvider.client.user.refreshToken',
        ),
        'refresh-token',
      );
      expect(
        values['CognitoIdentityServiceProvider.client.user.refreshToken'],
        '"refresh-token"',
      );
    });

    test('clears only Cognito keys on invalid session cleanup', () async {
      values.addAll(<String, String>{
        'CognitoIdentityServiceProvider.client.LastAuthUser': '"user"',
        'CognitoIdentityServiceProvider.client.user.accessToken': '"jwt"',
        'unrelated': '"keep"',
      });

      await storage.clear();

      expect(values, <String, String>{'unrelated': '"keep"'});
    });

    test('removes malformed cached values instead of reusing them', () async {
      values['CognitoIdentityServiceProvider.client.LastAuthUser'] = 'not-json';

      expect(
        await storage.getItem(
          'CognitoIdentityServiceProvider.client.LastAuthUser',
        ),
        isNull,
      );
      expect(values, isEmpty);
    });
  });
}
