import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as goong;

import '../config.dart';
import '../features/auth/auth_providers.dart';
import '../models/map_feed_item.dart';
import '../services/location_service.dart';
import '../services/map_feed_service.dart';
import 'ai_chat_screen.dart';
import 'camera_chat_inbox.dart';
import 'camera_screen.dart';
import 'dashboard.dart';
import 'home_ai_search_bar.dart';
import 'profile_screen.dart';

/// Home screen with Goong Map, current location, and check-in CTA.
class HomeScreen extends ConsumerStatefulWidget {
  final LocationService locationService;

  const HomeScreen({super.key, required this.locationService});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late final LocationService _locationService;
  goong.MapLibreMapController? _mapController;
  bool _mapStyleLoaded = false;
  bool _showLocationBanner = false;
  static const double _feedRefreshDistanceMeters = 50;
  static const Duration _feedRefreshMinInterval = Duration(seconds: 8);
  static const Distance _distance = Distance();

  StreamSubscription<LatLng>? _positionSubscription;
  LatLng? _lastFeedPosition;
  DateTime? _lastFeedFetchAt;
  bool _feedFetchInFlight = false;
  List<MapFeedItem> _feedItems = [];
  final Map<String, MapFeedItem> _feedItemsBySymbolId = <String, MapFeedItem>{};

  bool get _isLimitedMode => _locationService.status != LocationStatus.granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService = widget.locationService;
    _showLocationBanner = _locationService.status != LocationStatus.granted;
    _subscribeToPositionUpdates();
    if (_locationService.hasRealLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_fetchFeed());
      });
    }
  }

  void _subscribeToPositionUpdates() {
    _positionSubscription = _locationService.positionUpdates.listen(
      _handleRealtimeLocationUpdate,
    );

    if (_locationService.status == LocationStatus.granted) {
      unawaited(_locationService.startPositionUpdates());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_positionSubscription?.cancel());
    unawaited(_locationService.stopPositionUpdates());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLocationStatus());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_locationService.stopPositionUpdates());
    }
  }

  Future<void> _refreshLocationStatus() async {
    await _locationService.initialize();
    if (!mounted) return;
    setState(() {
      _showLocationBanner = _locationService.status != LocationStatus.granted;
    });
    if (_locationService.hasRealLocation) {
      unawaited(_animateToLocation(_locationService.currentPosition));
      unawaited(_fetchFeed());
      unawaited(_locationService.startPositionUpdates());
    }
  }

  void _handleRealtimeLocationUpdate(LatLng position) {
    if (!mounted) return;

    if (_showLocationBanner || _isLimitedMode) {
      setState(() {
        _showLocationBanner = _locationService.status != LocationStatus.granted;
      });
    }

    unawaited(_animateToLocation(position));

    if (_shouldFetchFeedForPosition(position)) {
      unawaited(_fetchFeed(center: position));
    }
  }

  bool _shouldFetchFeedForPosition(LatLng position) {
    if (_feedFetchInFlight) return false;

    final now = DateTime.now();
    final lastFeedFetchAt = _lastFeedFetchAt;
    if (lastFeedFetchAt != null &&
        now.difference(lastFeedFetchAt) < _feedRefreshMinInterval) {
      return false;
    }

    final lastFeedPosition = _lastFeedPosition;
    if (lastFeedPosition == null) return true;

    return _distance(lastFeedPosition, position) >= _feedRefreshDistanceMeters;
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

  goong.LatLng _toGoongLatLng(LatLng point) {
    return goong.LatLng(point.latitude, point.longitude);
  }

  goong.CameraPosition _initialCameraPosition() {
    return goong.CameraPosition(
      target: _toGoongLatLng(_locationService.currentPosition),
      zoom: _locationService.hasRealLocation ? 16.0 : 12.0,
    );
  }

  Future<void> _animateToLocation(LatLng target) async {
    final controller = _mapController;
    if (controller == null) return;

    await controller.animateCamera(
      goong.CameraUpdate.newLatLngZoom(_toGoongLatLng(target), 16.0),
    );
  }

  Future<void> _fetchFeed({LatLng? center}) async {
    if (_isLimitedMode || !_locationService.hasRealLocation) return;
    if (_feedFetchInFlight) return;

    final position = center ?? _locationService.currentPosition;
    _feedFetchInFlight = true;
    _lastFeedFetchAt = DateTime.now();

    try {
      final authService = ref.read(authServiceProvider);
      final mapFeedService = MapFeedService(authService);
      final items = await mapFeedService.getMapFeed(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        setState(() {
          _feedItems = items;
          _lastFeedPosition = position;
        });
        unawaited(_syncFeedSymbols());
      }
    } catch (e) {
      debugPrint('Error fetching feed: $e');
    } finally {
      _feedFetchInFlight = false;
    }
  }

  void _openAiChat(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AiChatScreen(initialMessage: trimmedQuery),
      ),
    );
  }

  String _feedMarkerLabel(MapFeedItem item) {
    final userName = item.userName.trim();
    if (userName.isEmpty) return '?';
    return userName.substring(0, 1).toUpperCase();
  }

  Future<void> _syncFeedSymbols() async {
    final controller = _mapController;
    if (controller == null || !_mapStyleLoaded) return;

    await controller.clearSymbols();
    _feedItemsBySymbolId.clear();

    for (final item in _feedItems) {
      final symbol = await controller.addSymbol(
        goong.SymbolOptions(
          geometry: goong.LatLng(item.lat, item.lng),
          textField: _feedMarkerLabel(item),
          textSize: 18,
          textColor: '#FFFFFF',
          textHaloColor: '#2563EB',
          textHaloWidth: 8,
          textAnchor: 'center',
          zIndex: 10,
        ),
      );
      _feedItemsBySymbolId[symbol.id] = item;
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

  void _onExplore() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
    );
  }

  void _onMessages() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const CameraChatInboxScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RepaintBoundary(
            child: Config.hasGoongMaptilesKey()
                ? goong.MapLibreMap(
                    initialCameraPosition: _initialCameraPosition(),
                    styleString: Config.goongStyleUrlWithKey(),
                    minMaxZoomPreference: const goong.MinMaxZoomPreference(
                      3.0,
                      20.0,
                    ),
                    myLocationEnabled: _locationService.hasRealLocation,
                    myLocationTrackingMode: goong.MyLocationTrackingMode.none,
                    compassEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      controller.onSymbolTapped.add((symbol) {
                        final item = _feedItemsBySymbolId[symbol.id];
                        if (item != null && mounted) {
                          _showFeedItemDetails(context, item);
                        }
                      });
                    },
                    onStyleLoadedCallback: () {
                      if (!mounted) return;
                      setState(() => _mapStyleLoaded = true);
                      unawaited(_syncFeedSymbols());
                    },
                  )
                : const _GoongMapConfigurationBanner(),
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
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        Expanded(
                          child: Center(
                            child: Image.asset(
                              'assets/images/logo_red.png',
                              height: 25,
                              cacheHeight: 96,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
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
                                  final authService = ref.watch(
                                    authServiceProvider,
                                  );
                                  final firstName = authService.firstName ?? '';
                                  final lastName = authService.lastName ?? '';
                                  String initials = 'U';
                                  if (firstName.isNotEmpty ||
                                      lastName.isNotEmpty) {
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
                                      image:
                                          authService.avatarUrl != null &&
                                              authService.avatarUrl!.isNotEmpty
                                          ? DecorationImage(
                                              image:
                                                  authService.avatarUrl!
                                                      .startsWith('http')
                                                  ? NetworkImage(
                                                          authService
                                                              .avatarUrl!,
                                                        )
                                                        as ImageProvider
                                                  : FileImage(
                                                      File(
                                                        authService.avatarUrl!,
                                                      ),
                                                    ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child:
                                        authService.avatarUrl == null ||
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
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: HomeAiSearchBar(onSubmitted: _openAiChat),
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
                    if (_locationService.status ==
                        LocationStatus.deniedForever) {
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
                      unawaited(
                        _animateToLocation(_locationService.currentPosition),
                      );
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
                    onTap: _onExplore,
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
                    onTap: _onMessages,
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

class _GoongMapConfigurationBanner extends StatelessWidget {
  const _GoongMapConfigurationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEF2),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'GOONG_MAPTILES_KEY chưa được cấu hình.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF1A1F2E),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
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
          const Icon(
            Icons.location_off_rounded,
            color: Color(0xFFEF4050),
            size: 18,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Chế độ giới hạn — chỉ có AI search',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    item.userName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.placeName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (item.caption.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              item.caption,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E17),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.image, color: Colors.white24, size: 48),
            ),
          ),
        ],
      ),
    );
  }
}
