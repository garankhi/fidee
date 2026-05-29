import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../features/auth/login_page.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

/// Home screen with OpenStreetMap, current location, and check-in CTA.
class HomeScreen extends StatefulWidget {
  final AuthService authService;

  const HomeScreen({super.key, required this.authService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _showLocationBanner = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    await _locationService.initialize();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _showLocationBanner = _locationService.status != LocationStatus.granted;
    });
  }

  void _animateToLocation(LatLng target) {
    _mapController.move(target, 16.0);
  }

  void _goToMyLocation() async {
    if (_locationService.status != LocationStatus.granted) {
      await _locationService.initialize();
      if (!mounted) return;
      setState(() {
        _showLocationBanner = _locationService.status != LocationStatus.granted;
      });
    }
    if (_locationService.hasRealLocation) {
      _animateToLocation(_locationService.currentPosition);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await widget.authService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(authService: widget.authService),
      ),
      (route) => false,
    );
  }

  void _onCheckIn() {
    // TODO: Navigate to check-in/camera screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tinh nang check-in dang phat trien...'),
        backgroundColor: Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E17),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // === MAP ===
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _locationService.currentPosition,
              initialZoom: _locationService.hasRealLocation ? 16.0 : 12.0,
              maxZoom: 18.0,
              minZoom: 3.0,
            ),
            children: [
              // Dark-style tile layer
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.mapvibe.mapvibe_mobile',
                maxZoom: 20,
              ),

              // Current location marker
              if (_locationService.hasRealLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _locationService.currentPosition,
                      width: 60,
                      height: 60,
                      child: const _PulsingLocationMarker(),
                    ),
                  ],
                ),
            ],
          ),

          // === TOP BAR (Search + Avatar) ===
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Search bar
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2E).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(
                          Icons.search,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Tim kiem dia diem...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Avatar / Menu
                GestureDetector(
                  onTap: () => _showProfileMenu(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // === LOCATION DENIED BANNER ===
          if (_showLocationBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 16,
              right: 16,
              child: _LocationDeniedBanner(
                status: _locationService.status,
                onAllow: () async {
                  if (_locationService.status == LocationStatus.deniedForever) {
                    await _locationService.openSettings();
                  } else {
                    await _locationService.initialize();
                  }
                  if (!mounted) return;
                  setState(() {
                    _showLocationBanner =
                        _locationService.status != LocationStatus.granted;
                  });
                  if (_locationService.hasRealLocation) {
                    _animateToLocation(_locationService.currentPosition);
                  }
                },
                onDismiss: () => setState(() => _showLocationBanner = false),
              ),
            ),

          // === MY LOCATION BUTTON ===
          Positioned(
            right: 16,
            bottom: 120,
            child: _FloatingButton(
              icon: Icons.my_location,
              onPressed: _goToMyLocation,
              size: 48,
              backgroundColor: const Color(0xFF1A1F2E).withValues(alpha: 0.95),
              iconColor: _locationService.hasRealLocation
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),

          // === CHECK-IN / CAMERA BUTTON ===
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(child: _CheckInButton(onPressed: _onCheckIn)),
          ),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Profile header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'MapVibe User',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // Sign out
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _signOut(context);
                  },
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text(
                    'Dang xuat',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFEF4444,
                    ).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFFEF4444),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// === PULSING LOCATION MARKER ===
class _PulsingLocationMarker extends StatefulWidget {
  const _PulsingLocationMarker();

  @override
  State<_PulsingLocationMarker> createState() => _PulsingLocationMarkerState();
}

class _PulsingLocationMarkerState extends State<_PulsingLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse
          Container(
            width: 60 * _animation.value,
            height: 60 * _animation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFF3B82F6,
              ).withValues(alpha: 0.2 * (1 - _animation.value)),
            ),
          ),
          // Inner dot
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3B82F6),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// === CHECK-IN BUTTON ===
class _CheckInButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CheckInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 180,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4050), Color(0xFFE91E63)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4050).withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Text(
              'Check-in',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === FLOATING BUTTON ===
class _FloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  const _FloatingButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}

// === LOCATION DENIED BANNER ===
class _LocationDeniedBanner extends StatelessWidget {
  final LocationStatus status;
  final VoidCallback onAllow;
  final VoidCallback onDismiss;

  const _LocationDeniedBanner({
    required this.status,
    required this.onAllow,
    required this.onDismiss,
  });

  String get _message {
    switch (status) {
      case LocationStatus.denied:
        return 'Cho phep vi tri de xem ban o dau tren ban do.';
      case LocationStatus.deniedForever:
        return 'Vi tri bi chan. Mo cai dat de bat lai.';
      case LocationStatus.serviceDisabled:
        return 'GPS dang tat. Bat GPS de xem vi tri.';
      default:
        return '';
    }
  }

  String get _buttonText {
    switch (status) {
      case LocationStatus.deniedForever:
        return 'Mo cai dat';
      case LocationStatus.serviceDisabled:
        return 'Bat GPS';
      default:
        return 'Cho phep';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Color(0xFFF59E0B), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAllow,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              foregroundColor: const Color(0xFF3B82F6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _buttonText,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
