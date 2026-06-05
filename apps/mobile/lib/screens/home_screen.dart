import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../features/auth/auth_providers.dart';
import '../models/map_feed_item.dart';
import '../models/nearby_place.dart';
import '../services/location_service.dart';
import '../services/map_feed_service.dart';
import '../services/nearby_service.dart';
import 'add_spot_screen.dart';
import 'camera_screen.dart';
import 'dashboard.dart';
import 'profile_screen.dart';

/// Home screen with OpenStreetMap, current location, and check-in CTA.
class HomeScreen extends ConsumerStatefulWidget {
  final LocationService locationService;

  const HomeScreen({super.key, required this.locationService});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final LocationService _locationService;
  final MapController _mapController = MapController();
  bool _showLocationBanner = false;
  List<MapFeedItem> _feedItems = [];

  bool get _isLimitedMode => _locationService.status != LocationStatus.granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService = widget.locationService;
    _showLocationBanner = _locationService.status != LocationStatus.granted;
    if (_locationService.hasRealLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchFeed();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationStatus();
    }
  }

  Future<void> _refreshLocationStatus() async {
    await _locationService.initialize();
    if (!mounted) return;
    setState(() {
      _showLocationBanner = _locationService.status != LocationStatus.granted;
    });
    if (_locationService.hasRealLocation) {
      _animateToLocation(_locationService.currentPosition);
      _fetchFeed();
    }
  }

  Future<void> _handleEnableLocation() async {
    if (_locationService.status == LocationStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else if (_locationService.status == LocationStatus.deniedForever) {
      await _locationService.openSettings();
    } else {
      await _refreshLocationStatus();
    }
  }

  void _animateToLocation(LatLng target) {
    _mapController.move(target, 16.0);
  }

  Future<void> _fetchFeed() async {
    if (_isLimitedMode || !_locationService.hasRealLocation) return;
    try {
      final authService = ref.read(authServiceProvider);
      final mapFeedService = MapFeedService(authService);
      final position = _locationService.currentPosition;
      final items = await mapFeedService.getMapFeed(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        setState(() {
          _feedItems = items;
        });
      }
    } catch (e) {
      debugPrint('Error fetching feed: $e');
    }
  }

  void _showFeedItemDetails(BuildContext context, MapFeedItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _FeedItemSheet(item: item),
    );
  }

  void _showLimitedModeSnack(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: Color(0xFFEF4050),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                await _handleEnableLocation();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4050).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Bật GPS',
                  style: TextStyle(
                    color: Color(0xFFEF4050),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1F2E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onCheckIn() async {
    if (_isLimitedMode) {
      _showLimitedModeSnack(
        'Check-in yêu cầu vị trí. Hãy bật GPS để dùng tính năng này.',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const CameraScreen()),
    );
  }

  void _onDiscover() async {
    List<NearbyPlace> localSpots = [];

    try {
      final nearbyService = NearbyService(ref.read(authServiceProvider));
      final res = await nearbyService.fetchNearby(
        lat: _locationService.currentPosition.latitude,
        lng: _locationService.currentPosition.longitude,
        mediaId: 'discover_${DateTime.now().millisecondsSinceEpoch}',
      );
      localSpots = res.data.where((p) => !p.isCustomFallback).toList();
    } catch (e) {
      debugPrint('Error loading nearby spots for dashboard flow: $e');
    }

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: DashboardScreen(
            spotSuggestions: localSpots,
            onAddSpot: (spots) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AddSpotScreen(
                    spotSuggestions: spots,
                    authService: ref.read(authServiceProvider),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
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
                TileLayer(
                  urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.fidee.fidee',
                  maxZoom: 20,
                ),
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
                if (_feedItems.isNotEmpty)
                  MarkerLayer(
                    markers: _feedItems
                        .map(
                          (item) => Marker(
                        point: LatLng(item.lat, item.lng),
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () => _showFeedItemDetails(context, item),
                          child: _FeedMarker(item: item),
                        ),
                      ),
                    )
                        .toList(),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _TopAddSpotButton(onTap: _onDiscover),
                        Image.asset(
                          'assets/images/logo_red.png',
                          height: 25,
                          cacheHeight: 96,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          },
                          child: Consumer(
                            builder: (context, ref, _) {
                              final authService = ref.watch(authServiceProvider);
                              final firstName = authService.firstName ?? '';
                              final lastName = authService.lastName ?? '';
                              String initials = 'U';
                              if (firstName.isNotEmpty || lastName.isNotEmpty) {
                                final first = firstName.trim().isNotEmpty
                                    ? firstName.trim().substring(0, 1)
                                    : '';
                                final last = lastName.trim().isNotEmpty
                                    ? lastName.trim().substring(0, 1)
                                    : '';
                                initials = '$first$last'.toUpperCase();
                                if (initials.isEmpty) initials = 'U';
                              } else if (authService.username != null &&
                                  authService.username!.isNotEmpty) {
                                initials = authService.username!
                                    .substring(0, 1)
                                    .toUpperCase();
                              }

                              return Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4050),
                                  shape: BoxShape.circle,
                                  image: authService.avatarUrl != null &&
                                      authService.avatarUrl!.isNotEmpty
                                      ? DecorationImage(
                                    image: authService.avatarUrl!.startsWith('http')
                                        ? NetworkImage(authService.avatarUrl!) as ImageProvider
                                        : FileImage(File(authService.avatarUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                      : null,
                                ),
                                child: authService.avatarUrl == null ||
                                    authService.avatarUrl!.isEmpty
                                    ? Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                                    : null,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      _showLocationBanner = _locationService.status != LocationStatus.granted;
                    });
                    if (_locationService.hasRealLocation) {
                      _animateToLocation(_locationService.currentPosition);
                    }
                  },
                  onDismiss: () => setState(() => _showLocationBanner = false),
                ),
              ),
            ),

          // === LIMITED MODE BANNER ===
          if (_isLimitedMode)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: RepaintBoundary(
                child: _LimitedModeBanner(onEnable: _handleEnableLocation),
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
                  _BottomNavIcon(
                    assetPath: 'assets/icons/Discovery.png',
                    onTap: _onDiscover,
                    size: 60,
                    iconSize: 42,
                    locked: _isLimitedMode,
                  ),
                  const SizedBox(width: 24),
                  _BottomNavIcon(
                    assetPath: 'assets/icons/Camera.png',
                    onTap: _onCheckIn,
                    size: 76,
                    iconSize: 74,
                    locked: _isLimitedMode,
                  ),
                  const SizedBox(width: 24),
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
}

class _TopAddSpotButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TopAddSpotButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_location_alt_rounded,
          color: Color(0xFFEF4050),
          size: 22,
        ),
      ),
    );
  }
}

class _BottomNavIcon extends StatelessWidget {
  final String assetPath;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool locked;

  const _BottomNavIcon({
    required this.assetPath,
    required this.onTap,
    this.size = 60,
    this.iconSize = 28,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.38 : 1.0,
        child: Stack(
          alignment: Alignment.topRight,
          clipBehavior: Clip.none,
          children: [
            Container(
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
            if (locked)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B95A1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.lock, color: Colors.white, size: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
            Container(
              width: 60 * _animation.value,
              height: 60 * _animation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.2 * (1 - _animation.value)),
              ),
            ),
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
            child: const Icon(Icons.close, color: Colors.black38, size: 18),
          ),
        ],
      ),
    );
  }
}

class _LimitedModeBanner extends StatelessWidget {
  final VoidCallback onEnable;
  const _LimitedModeBanner({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4050).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: Color(0xFFEF4050), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Chế độ giới hạn — chỉ có AI search',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEnable,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4050).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Bật GPS',
                style: TextStyle(color: Color(0xFFEF4050), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedMarker extends StatelessWidget {
  final MapFeedItem item;
  const _FeedMarker({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          item.userName.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );
  }
}

class _FeedItemSheet extends StatelessWidget {
  final MapFeedItem item;
  const _FeedItemSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    item.userName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(item.placeName, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                  ],
                ),
              ),
              Text(
                '${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
              ),
            ],
          ),
          if (item.caption.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(item.caption, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(color: const Color(0xFF0A0E17), borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Icon(Icons.image, color: Colors.white24, size: 48)),
          ),
        ],
      ),
    );
  }
}