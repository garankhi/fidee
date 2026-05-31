import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../features/auth/auth_providers.dart';
import '../services/location_service.dart';
import 'camera_screen.dart';

/// Home screen with OpenStreetMap, current location, and check-in CTA.
///
/// [locationService] được truyền vào từ main.dart đã resolve sẵn thông qua
/// [locationControllerProvider]. HomeScreen không cần tự khởi động location
/// và không hiển thị spinner trắng — map render ngay lập tức.
class HomeScreen extends ConsumerStatefulWidget {
  final LocationService locationService;

  const HomeScreen({super.key, required this.locationService});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final LocationService _locationService;
  final MapController _mapController = MapController();
  bool _showLocationBanner = false;

  @override
  void initState() {
    super.initState();
    // LocationService đã được khởi động song song với auth trong main.dart.
    // Không cần _initLocation() hay spinner — dùng thẳng kết quả đã có.
    _locationService = widget.locationService;
    _showLocationBanner = _locationService.status != LocationStatus.granted;
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
    await ref.read(authControllerProvider.notifier).signOut();
  }

  void _onCheckIn() async {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const CameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Không còn _isLoading guard — map render ngay từ frame đầu tiên.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // === MAP ===
          RepaintBoundary(
            child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _locationService.currentPosition,
              initialZoom: _locationService.hasRealLocation ? 16.0 : 12.0,
              maxZoom: 18.0,
              minZoom: 3.0,
            ),
            children: [
              // Light-style tile layer (Voyager)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.fidee.fidee_mobile',
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
          ),

          // === TOP UI (Logo, Avatar, Search) ===
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: Column(
                children: [
                // Logo & Avatar Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40), // Balance the avatar
                      Image.asset(
                        'assets/images/logo.png',
                        height: 32,
                        cacheHeight: 96,
                      ),
                      GestureDetector(
                        onTap: () => _showProfileMenu(context),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFF5A8DEE),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'AA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Center(
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xFFFF3B30)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Want something today?',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.mic, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          // === LOCATION DENIED BANNER ===
          if (_showLocationBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 140,
              left: 16,
              right: 16,
              child: RepaintBoundary(
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
            ),

            // === BOTTOM BUTTONS ===
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Compass (Left)
                    _BottomNavIcon(
                      assetPath: 'assets/icons/Discovery.png',
                      onTap: _goToMyLocation,
                      size: 60,
                      iconSize: 42,
                    ),
                    const SizedBox(width: 24),
                    // Camera (Center)
                    _BottomNavIcon(
                      assetPath: 'assets/icons/Camera.png',
                      onTap: _onCheckIn,
                      size: 76,
                      iconSize: 32,
                    ),
                    const SizedBox(width: 24),
                    // Messages (Right)
                    _BottomNavIcon(
                      assetPath: 'assets/icons/Chat.png',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Messages clicked')),
                        );
                      },
                      size: 60,
                      iconSize: 75,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Profile header
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF5A8DEE),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Center(
                child: Text(
                  'AA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'User',
              style: TextStyle(
                color: Colors.black87,
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
                label: const Text('Dang xuat', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
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
    );
  }
}

  // === BOTTOM NAV ICON ===
  class _BottomNavIcon extends StatelessWidget {
    final String assetPath;
    final VoidCallback onTap;
    final double size;
    final double iconSize;
  
    const _BottomNavIcon({
      required this.assetPath,
      required this.onTap,
      this.size = 60,
      this.iconSize = 28, // <-- ĐÂY LÀ CHỖ TĂNG KÍCH THƯỚC ICON MẶC ĐỊNH
    });
  
    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              assetPath,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              cacheWidth: 152,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error, color: Colors.grey),
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
    return RepaintBoundary(
      child: AnimatedBuilder(
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
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2 * (1 - _animation.value)),
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
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAllow,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
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
            child: const Icon(
              Icons.close,
              color: Colors.black38,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
