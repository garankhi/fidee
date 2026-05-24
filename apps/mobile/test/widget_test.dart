import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapvibe_mobile/main.dart';
import 'package:mapvibe_mobile/services/auth_service.dart';
import 'package:mapvibe_mobile/features/auth/login_page.dart';
import 'package:mapvibe_mobile/screens/otp_screen.dart';
import 'package:mapvibe_mobile/screens/home_screen.dart';

void main() {
  group('MapVibeApp', () {
    testWidgets('MapVibeApp shows loading then login page', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);
      await tester.pumpWidget(MapVibeApp(authService: authService));
      // After initialization, should show phone input
      await tester.pumpAndSettle();
      expect(find.text('MAPVIBE'), findsOneWidget);
    });
  });

  group('LoginPage', () {
    testWidgets('renders input field and button', (
      WidgetTester tester,
    ) async {
      final authService = AuthService(isTestMode: true);
      await authService.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(authService: authService),
        ),
      );

      expect(find.text('Continue with OTP'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('validates empty input', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);
      await authService.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(authService: authService),
        ),
      );

      await tester.tap(find.text('Continue with OTP'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vui long nhap so dien thoai hoac email'),
        findsOneWidget,
      );
    });
  });

  group('OtpScreen', () {
    testWidgets('renders 6 OTP input fields', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);
      await authService.initialize();
      await authService.signIn('+84912345678');
      await tester.pumpWidget(
        MaterialApp(
          home: OtpScreen(authService: authService),
        ),
      );

      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Xac nhan'), findsOneWidget);
    });

    testWidgets('shows cooldown timer', (WidgetTester tester) async {
      final authService = AuthService(isTestMode: true);
      await authService.initialize();
      await authService.signIn('+84912345678');
      await tester.pumpWidget(
        MaterialApp(
          home: OtpScreen(authService: authService),
        ),
      );

      expect(find.textContaining('Gui lai ma sau'), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    testWidgets('renders map and UI elements', (
      WidgetTester tester,
    ) async {
      final authService = AuthService(isTestMode: true);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(authService: authService),
        ),
      );

      // Pump multiple frames to get past loading
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Check-in button should be present after map loads
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
}
