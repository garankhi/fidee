import 'dart:async';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'features/auth/login_page.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MapVibeApp());
}

class MapVibeApp extends StatefulWidget {
  final AuthService? authService;
  
  const MapVibeApp({super.key, this.authService});

  @override
  State<MapVibeApp> createState() => _MapVibeAppState();
}

class _MapVibeAppState extends State<MapVibeApp> {
  late final AuthService _authService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _initialize();
  }

  Future<void> _initialize() async {
    await _authService.initialize();
    setState(() => _isInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapVibe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        primaryColor: const Color(0xFF3B82F6),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF1A1F2E),
          error: Color(0xFFEF4444),
        ),
        fontFamily: 'Inter',
      ),
      home: _isInitialized
          ? _authService.state == AuthState.authenticated
              ? HomeScreen(authService: _authService)
              : LoginPage(authService: _authService)
          : const Scaffold(
              backgroundColor: Color(0xFF0A0E17),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
    );
  }
}
