import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
import 'place_details_friends.dart';
import 'profile_screen.dart';

enum MapFeedMode { friends, private }

class MapFeedMarkerPresentation {
  static const int maxLabelChars = 14;
  static const double labelHorizontalPadding = 3.0;
  static const double minLabelWidth = 44.0;
  static const double maxLabelWidth = 160.0;

  final IconData icon;
  final String label;
  final Color accent;
  final bool isCandidate;

  const MapFeedMarkerPresentation({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isCandidate,
  });

  factory MapFeedMarkerPresentation.fromItem(MapFeedItem item) {
    final isPrivate =
        item.visibility == 'PRIVATE' || item.checkinVisibility == 'PRIVATE';
    return MapFeedMarkerPresentation(
      icon: _iconForCategory(item.category),
      label: _shortPlaceLabel(item.placeName),
      accent: isPrivate ? const Color(0xFF374151) : const Color(0xFFEF4050),
      isCandidate: item.isCandidate,
    );
  }

  static IconData _iconForCategory(String category) {
    return switch (category) {
      'cafe' => Icons.local_cafe_rounded,
      'restaurant' => Icons.restaurant_rounded,
      'hotel' => Icons.hotel_rounded,
      'tourist_attraction' => Icons.photo_camera_rounded,
      'office' => Icons.business_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      _ => Icons.place_rounded,
    };
  }

  static double labelPillWidth(double textWidth) {
    return (textWidth + labelHorizontalPadding * 2).clamp(
      minLabelWidth,
      maxLabelWidth,
    );
  }

  static String _shortPlaceLabel(String placeName) {
    final normalized = placeName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return 'Địa điểm';
    if (normalized.length <= maxLabelChars) return normalized;
    return '${normalized.substring(0, maxLabelChars)}…';
  }
}

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
  MapFeedMode _feedMode = MapFeedMode.friends;
  List<MapFeedItem> _feedItems = [];
  final Map<String, MapFeedItem> _feedItemsBySymbolId = <String, MapFeedItem>{};
  final Set<String> _registeredMarkerImages = <String>{};

  bool get _isLimitedMode => _locationService.status != LocationStatus.granted;

  List<MapFeedItem> get _visibleFeedItems {
    return _feedItems.where((item) {
      final isPrivate = _isPrivateFeedItem(item);
      return _feedMode == MapFeedMode.private ? isPrivate : !isPrivate;
    }).toList(growable: false);
  }

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

  void _openAiChat([String query = '']) {
    final trimmedQuery = query.trim();

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AiChatScreen(
          initialMessage: trimmedQuery.isEmpty ? null : trimmedQuery,
        ),
      ),
    );
  }

  bool _isPrivateFeedItem(MapFeedItem item) {
    return item.visibility == 'PRIVATE' || item.checkinVisibility == 'PRIVATE';
  }

  void _toggleFeedMode() {
    setState(() {
      _feedMode = _feedMode == MapFeedMode.friends
          ? MapFeedMode.private
          : MapFeedMode.friends;
    });
    unawaited(_syncFeedSymbols());
  }

  String _markerImageName(MapFeedItem item) {
    final presentation = MapFeedMarkerPresentation.fromItem(item);
    final privacy = _isPrivateFeedItem(item) ? 'private' : 'friends';
    final candidate = item.isCandidate ? 'candidate' : 'place';
    return 'feed-marker-$privacy-$candidate-${item.placeId}-${item.category}-${presentation.label.hashCode}';
  }

  Future<String> _ensureMarkerImage(
    goong.MapLibreMapController controller,
    MapFeedItem item,
  ) async {
    final name = _markerImageName(item);
    if (_registeredMarkerImages.contains(name)) return name;

    final bytes = await _buildMarkerImageBytes(item);
    await controller.addImage(name, bytes);
    _registeredMarkerImages.add(name);
    return name;
  }

  Future<Uint8List> _buildMarkerImageBytes(MapFeedItem item) async {
    final presentation = MapFeedMarkerPresentation.fromItem(item);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(192, 116);
    const iconCenter = Offset(96, 32);
    const iconRadius = 24.0;
    const labelTop = 60.0;
    const labelHeight = 34.0;
    final accent = presentation.accent;

    final labelPainter = TextPainter(
      text: TextSpan(
        text: presentation.label,
        style: TextStyle(
          color: accent,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      maxLines: 1,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      ellipsis: '…',
    )..layout(maxWidth: MapFeedMarkerPresentation.maxLabelWidth);
    final labelWidth = MapFeedMarkerPresentation.labelPillWidth(
      labelPainter.width,
    );
    final labelRect = Rect.fromLTWH(
      (size.width - labelWidth) / 2,
      labelTop,
      labelWidth,
      labelHeight,
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        labelRect.translate(0, 4),
        const Radius.circular(17),
      ),
      shadowPaint,
    );
    canvas.drawCircle(iconCenter.translate(0, 5), iconRadius, shadowPaint);

    final pointerPath = ui.Path()
      ..moveTo(88, 92)
      ..lineTo(104, 92)
      ..lineTo(96, 110)
      ..close();
    canvas.drawPath(pointerPath, Paint()..color = Colors.white);

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(17)),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(iconCenter, iconRadius + 4, Paint()..color = Colors.white);
    canvas.drawCircle(iconCenter, iconRadius, Paint()..color = accent);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(presentation.icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontFamily: presentation.icon.fontFamily,
          fontSize: 27,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(
        iconCenter.dx - iconPainter.width / 2,
        iconCenter.dy - iconPainter.height / 2,
      ),
    );

    if (presentation.isCandidate) {
      const badgeCenter = Offset(116, 16);
      canvas.drawCircle(badgeCenter, 8, Paint()..color = Colors.white);
      canvas.drawCircle(badgeCenter, 5, Paint()..color = accent);
    }

    labelPainter.layout(
      maxWidth:
          labelRect.width - MapFeedMarkerPresentation.labelHorizontalPadding * 2,
    );
    labelPainter.paint(
      canvas,
      Offset(
        labelRect.left + (labelRect.width - labelPainter.width) / 2,
        labelRect.top + (labelRect.height - labelPainter.height) / 2,
      ),
    );

    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _syncFeedSymbols() async {
    final controller = _mapController;
    if (controller == null || !_mapStyleLoaded) return;

    await controller.clearSymbols();
    _feedItemsBySymbolId.clear();

    for (final item in _visibleFeedItems) {
      final imageName = await _ensureMarkerImage(controller, item);
      final symbol = await controller.addSymbol(
        goong.SymbolOptions(
          geometry: goong.LatLng(item.lat, item.lng),
          iconImage: imageName,
          iconSize: 2.3,
          iconAnchor: 'bottom',
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
      builder: (ctx) => FeedPlaceSheet(
        item: item,
        onViewDetails: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PlaceDetailsFriends(placeId: item.placeId),
            ),
          );
        },
      ),
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
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const CameraScreen()),
    );
    if (!mounted) return;
    unawaited(_fetchFeed(center: _locationService.currentPosition));
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
                      _registeredMarkerImages.clear();
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
                    child: HomeAiSearchBar(
                      onSubmitted: _openAiChat,
                      onOpenChat: _openAiChat,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 130,
            right: 16,
            child: RepaintBoundary(
              child: MapModeToggleButton(
                mode: _feedMode,
                onTap: _toggleFeedMode,
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
        return 'Cho phép vị trí để xem bạn ở đâu trên bản đồ.';
      case LocationStatus.deniedForever:
        return 'Vị trí bị chặn. Mở cài đặt để bật lại.';
      case LocationStatus.serviceDisabled:
        return 'GPS đang tắt. Bật GPS để xem vị trí.';
      default:
        return '';
    }
  }

  String get _buttonText {
    switch (status) {
      case LocationStatus.deniedForever:
        return 'Mở cài đặt';
      case LocationStatus.serviceDisabled:
        return 'Bật GPS';
      default:
        return 'Cho phép';
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

class MapModeToggleButton extends StatelessWidget {
  final MapFeedMode mode;
  final VoidCallback onTap;

  const MapModeToggleButton({super.key, required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPrivate = mode == MapFeedMode.private;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isPrivate
                  ? const Color(0xFF374151).withValues(alpha: 0.18)
                  : const Color(0xFFEF4050).withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPrivate ? Icons.lock_rounded : Icons.group_rounded,
                size: 16,
                color: isPrivate
                    ? const Color(0xFF374151)
                    : const Color(0xFFEF4050),
              ),
              const SizedBox(width: 7),
              Text(
                isPrivate ? 'Riêng tư' : 'Bạn bè',
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.swap_horiz_rounded,
                size: 15,
                color: Color(0xFF8B95A1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedPlaceSheet extends StatelessWidget {
  final MapFeedItem item;
  final VoidCallback? onViewDetails;

  const FeedPlaceSheet({super.key, required this.item, this.onViewDetails});

  String get _categoryLabel {
    return switch (item.category) {
      'cafe' => 'Cafe',
      'restaurant' => 'Nhà hàng',
      'hotel' => 'Khách sạn',
      'tourist_attraction' => 'Du lịch',
      'office' => 'Văn phòng',
      'shopping' => 'Mua sắm',
      _ => 'Địa điểm',
    };
  }

  String get _contextChip {
    if (item.visibility == 'PRIVATE' || item.checkinVisibility == 'PRIVATE') {
      return 'Riêng tư';
    }
    if (item.isCandidate) return 'Địa điểm bạn bè đề xuất';
    return _categoryLabel;
  }

  String get _latestLine {
    if (item.isCandidate && item.placeCheckinCount == 0) {
      final creatorName = item.createdByName?.trim();
      if (creatorName != null && creatorName.isNotEmpty) {
        return '$creatorName đã tạo địa điểm này';
      }
      return 'Địa điểm mới được đề xuất';
    }

    final latestUser = item.userName.trim().isNotEmpty ? item.userName.trim() : 'Bạn bè';
    final caption = item.caption.trim();
    if (caption.isEmpty) return '$latestUser vừa check-in tại đây';
    return '$latestUser vừa check-in: $caption';
  }

  String get _checkinCountLabel {
    if (item.placeCheckinCount == 0) return 'Chưa có check-in';
    return '${item.placeCheckinCount} check-ins gần đây';
  }

  @override
  Widget build(BuildContext context) {
    final address = item.address?.trim();
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomSafeArea),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.placeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 24,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (address != null && address.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8B95A1),
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FeedAvatarStack(
                  names: item.recentUserNames.isEmpty
                      ? <String>[item.userName]
                      : item.recentUserNames,
                  avatars: item.recentAvatars,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FeedChip(label: _contextChip),
                _FeedChip(label: _checkinCountLabel),
                if (item.createdByName != null && item.createdByName!.isNotEmpty)
                  _FeedChip(label: 'Tạo bởi ${item.createdByName}'),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  _InitialAvatar(name: item.userName, avatarUrl: item.userAvatar),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _latestLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onViewDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4050),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Xem chi tiết',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class FeedAvatarStack extends StatelessWidget {
  final List<String> names;
  final List<String> avatars;

  const FeedAvatarStack({
    super.key,
    required this.names,
    required this.avatars,
  });

  @override
  Widget build(BuildContext context) {
    final count = names.isEmpty ? 1 : names.length.clamp(1, 3);
    return SizedBox(
      width: 34.0 + (count - 1) * 22.0,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < count; index++)
            Positioned(
              left: index * 22,
              child: _InitialAvatar(
                name: index < names.length ? names[index] : '',
                avatarUrl: index < avatars.length ? avatars[index] : null,
                size: 34,
              ),
            ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _InitialAvatar({required this.name, this.avatarUrl, this.size = 38});

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4050),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        image: url != null && url.startsWith('http')
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: url == null || !url.startsWith('http')
          ? Center(
              child: Text(
                _initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }
}

class _FeedChip extends StatelessWidget {
  final String label;

  const _FeedChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4050).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFEF4050),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
