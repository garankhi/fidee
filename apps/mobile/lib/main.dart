import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_providers.dart';
import 'features/auth/login_page.dart';
import 'features/auth/screens/complete_profile_page.dart';

import 'screens/home_screen.dart';
import 'screens/location_gate_screen1.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FideeApp()));
}

class FideeApp extends ConsumerWidget {
  const FideeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    // Kick off location init ngay từ đầu, chạy song song với auth.
    // Riverpod sẽ cache kết quả (keepAlive), HomeScreen dùng lại mà không phải chờ.
    final locationState = ref.watch(locationControllerProvider);

    return MaterialApp(
      title: 'Fidee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        primaryColor: const Color(0xFFEF4050),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEF4050),
          secondary: Color(0xFFEF4050),
          surface: Color(0xFF1A1F2E),
          error: Color(0xFFEF4444),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFFEF4050),
          selectionColor: Color(0x4DEF4050),
          selectionHandleColor: Color(0xFFEF4050),
        ),
        fontFamily: 'SF Pro',

      ),
      // Giữ SplashScreen cho đến khi CẢ auth VÀ location đã resolve.
      // Luồng: SplashScreen (đỏ) → HomeScreen với map sẵn sàng, không có spinner trắng.
      home: _buildHome(authState, locationState),
    );
  }

  Widget _buildHome(
    AsyncValue<AuthUiState> authState,
    AsyncValue<LocationService> locationState,
  ) {
    // Still loading on any provider without a previous value → hold on native splash
    if ((authState.isLoading && !authState.hasValue) ||
        (locationState.isLoading && !locationState.hasValue)) {
      return const SizedBox.expand();
    }

    // Auth error → go to LoginPage
    if (authState.hasError) {
      return const LoginPage();
    }

    final state = authState.value!;

    if (state.authState == AuthState.authenticated) {
      // Location resolved (or error dismissed with default fallback)
      final locationService = locationState.valueOrNull ?? LocationService();

      // If location permission not granted → show gate screen before entering map
      if (locationService.status != LocationStatus.granted) {
        return LocationGateScreen(locationService: locationService);
      }

      return HomeScreen(locationService: locationService);
    } else if (state.authState == AuthState.incompleteProfile) {
      // Authenticated user is missing required profile fields.
      // Keep this outside the register wizard so users do not feel sent back to signup.
      return CompleteProfilePage(
        initialFirstName: state.firstName,
        initialLastName: state.lastName,
        initialUsername: state.preferredUsername,
      );
    } else {
      return const LoginPage();
    }
  }
}

