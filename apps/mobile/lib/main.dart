import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_providers.dart';
import 'features/auth/login_page.dart';
import 'features/auth/screens/register_step3_name_page.dart';
import 'screens/camera_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FideeApp()));
}

class FideeApp extends ConsumerWidget {
  const FideeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

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
        fontFamily: 'Inter',
      ),
      home: authState.when(
        loading: () => const _SplashScreen(),
        error: (_, _) => const LoginPage(),
        data: (state) {
          if (state.authState == AuthState.authenticated) {
            return const CameraScreen();
          } else if (state.authState == AuthState.incompleteProfile) {
            // BEST PRACTICE: Bắt lỗi đăng ký dở dang, ép vào màn nhập Tên
            return const RegisterStep3NamePage();
          } else {
            return const LoginPage();
          }
        },
      ),
      
    );
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
          image: AssetImage('assets/images/logo.png'),
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
