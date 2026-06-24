import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_providers.dart';
import 'features/auth/chat_provider.dart';
import 'features/auth/friend_realtime_provider.dart';
import 'features/auth/friends_provider.dart';
import 'features/auth/login_page.dart';
import 'features/auth/screens/complete_profile_page.dart';
import 'screens/home_screen.dart';
import 'screens/location_gate_screen1.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  if (!kReleaseMode) {
    await dotenv.load(fileName: 'assets/env/mobile.env', isOptional: true);
  }
  // MVP publish: RevenueCat/payment is intentionally disabled.
  // try {
  //   await const RevenueCatService().configure();
  // } catch (error) {
  //   if (kDebugMode) {
  //     debugPrint('RevenueCat is not configured for this runtime: $error');
  //   }
  // }
  runApp(const ProviderScope(child: FideeApp()));
}

bool shouldKeepNativeSplash(
  AsyncValue<AuthUiState> authState,
  AsyncValue<LocationService> locationState,
) {
  return (authState.isLoading && !authState.hasValue) ||
      (locationState.isLoading && !locationState.hasValue);
}

class FideeApp extends ConsumerStatefulWidget {
  const FideeApp({super.key});

  @override
  ConsumerState<FideeApp> createState() => _FideeAppState();
}

class _FideeAppState extends ConsumerState<FideeApp> {
  bool _nativeSplashRemoved = false;
  String? _lastUserScopedProviderSub;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Kick off location status check ngay từ đầu, chạy song song với auth.
    // Riverpod sẽ cache kết quả (keepAlive), HomeScreen dùng lại mà không phải chờ.
    final locationState = ref.watch(locationControllerProvider);
    final keepNativeSplash = shouldKeepNativeSplash(authState, locationState);

    if (!keepNativeSplash) {
      _removeNativeSplashAfterReadyFrame();
    }

    return MaterialApp(
      key: ValueKey(authState.valueOrNull?.authState ?? AuthState.loading),
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
      // Native splash stays on top until auth and location both resolve.
      // Flutter renders a blank placeholder behind it to avoid a second splash screen.
      home: _buildHome(authState, locationState, keepNativeSplash),
    );
  }

  void _removeNativeSplashAfterReadyFrame() {
    if (_nativeSplashRemoved) {
      return;
    }

    _nativeSplashRemoved = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  Widget _buildHome(
    AsyncValue<AuthUiState> authState,
    AsyncValue<LocationService> locationState,
    bool keepNativeSplash,
  ) {
    if (keepNativeSplash) {
      return const SizedBox.expand();
    }

    // Auth lỗi → về LoginPage
    if (authState.hasError) {
      return const LoginPage();
    }

    final state = authState.value!;

    if (state.authState == AuthState.authenticated) {
      unawaited(ref.read(friendRealtimeControllerProvider).connect());
      unawaited(ref.read(chatRealtimeControllerProvider).connect());
      unawaited(_refreshUserScopedProviders());

      // Location đã resolve (hoặc lỗi được bỏ qua với fallback mặc định)
      final locationService = locationState.valueOrNull ?? LocationService();

      // Nếu location chưa được cấp phép → hiển thị gate screen trước khi vào map
      if (locationService.status != LocationStatus.granted) {
        return LocationGateScreen(locationService: locationService);
      }

      return HomeScreen(locationService: locationService);
    } else if (state.authState == AuthState.incompleteProfile) {
      _lastUserScopedProviderSub = null;
      unawaited(ref.read(friendRealtimeControllerProvider).disconnect());
      unawaited(ref.read(chatRealtimeControllerProvider).disconnect());

      // Authenticated user is missing required profile fields.
      // Keep this outside the register wizard so users do not feel sent back to signup.
      return CompleteProfilePage(
        initialFirstName: state.firstName,
        initialLastName: state.lastName,
        initialUsername: state.preferredUsername,
      );
    } else {
      _lastUserScopedProviderSub = null;
      unawaited(ref.read(friendRealtimeControllerProvider).disconnect());
      unawaited(ref.read(chatRealtimeControllerProvider).disconnect());
      return const LoginPage();
    }
  }

  Future<void> _refreshUserScopedProviders() async {
    final authService = ref.read(authServiceProvider);
    final userId = await authService.getCurrentUserSub();
    if (!mounted || userId == null || userId.isEmpty) return;
    if (_lastUserScopedProviderSub == userId) return;

    _lastUserScopedProviderSub = userId;
    unawaited(ref.read(friendsControllerProvider.notifier).load());
    unawaited(ref.read(chatInboxControllerProvider.notifier).load());
  }
}
