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
    // Còn loading ở bất kỳ provider nào và chưa có giá trị cũ → giữ SplashScreen
    if ((authState.isLoading && !authState.hasValue) ||
        (locationState.isLoading && !locationState.hasValue)) {
      return const _SplashScreen();
    }

    // Auth lỗi → về LoginPage
    if (authState.hasError) {
      return const LoginPage();
    }

    final state = authState.value!;

    if (state.authState == AuthState.authenticated) {
      // Location đã resolve (hoặc lỗi được bỏ qua với fallback mặc định)
      final locationService = locationState.valueOrNull ?? LocationService();

      // Nếu location chưa được cấp phép → hiển thị gate screen trước khi vào map
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFEF4050),
      body: Center(
        child: Image(
          image: AssetImage('assets/images/logo_fire.png'),
          width: 260,
          height: 260,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
