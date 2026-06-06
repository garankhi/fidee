import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/friends_provider.dart';
import '../models/nearby_place.dart';
import '../models/selected_place_tag.dart';
import '../services/location_service.dart';
import '../services/nearby_service.dart';
import '../services/place_candidate_service.dart';
import '../services/upload_service.dart';
import '../utils/error.dart';
import 'camera_screen.dart';
import 'place_picker_sheet.dart';

class SendImageScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String source; // 'IN_APP_CAMERA' or 'EXIF_GALLERY'

  /// GPS coordinates supplied by the image source when available.
  /// Gallery images may provide [latitude, longitude] from EXIF data.
  /// Camera captures no longer block preview on a GPS lookup.

  final List<double>? gpsCoordinates;

  const SendImageScreen({
    super.key,
    required this.imagePath,
    required this.source,
    this.gpsCoordinates,
  });

  @override
  ConsumerState<SendImageScreen> createState() => _SendImageScreenState();
}

enum _UploadStatus { idle, pending, error }

class _SendImageScreenState extends ConsumerState<SendImageScreen> {
  _UploadStatus _uploadStatus = _UploadStatus.idle;
  List<NearbyPlace> _nearbySpots = [];
  SelectedPlaceTag? _selectedPlace;

  // Data cho các caption
  String _timeString = '00:00';
  Timer? _clockTimer;

  // State cho text pill mặc định
  final TextEditingController _messageController = TextEditingController();
  bool _isEditingMessage = false;

  // Carousel state
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final int _totalCaptions = 4;

  @override
  void initState() {
    super.initState();
    _startClock();
  }



  @override
  void dispose() {
    _clockTimer?.cancel();
    _messageController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  void _startClock() {
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = DateFormat('h:mm a').format(now);
    });
  }
  List<double> _placeLookupCoordinates() {
    final locationService = ref.read(locationControllerProvider).valueOrNull;
    final position = locationService?.currentPosition ?? LocationService.defaultLocation;
    return [position.latitude, position.longitude];
  }

  Future<List<NearbyPlace>> _fetchNearbySpots() async {
    final coordinates = _placeLookupCoordinates();
    final authService = ref.read(authServiceProvider);
    final nearbyService = NearbyService(authService);

    final res = await nearbyService.fetchNearby(
      lat: coordinates[0],
      lng: coordinates[1],
      radius: 1000,
    );

    return res.data.where((p) => !p.isCustomFallback).toList();
  }

  Future<SelectedPlaceTag?> _createCustomPlaceTag(String name) async {
    final coordinates = _placeLookupCoordinates();
    try {
      final response = await PlaceCandidateService(
        ref.read(authServiceProvider),
      ).createCandidate(
        name: name,
        category: 'restaurant',
        lat: coordinates[0],
        lng: coordinates[1],
      );

      if (!response.isCreated || response.data == null) return null;

      final data = response.data!;
      return SelectedPlaceTag(
        id: data.candidateId,
        displayName: data.name,
        address: 'Được tạo bởi Bạn',
        lat: coordinates[0],
        lng: coordinates[1],
        source: 'custom',
      );
    } catch (e) {
      debugPrint('Create custom place failed: $e');
      return null;
    }
  }

  NearbyPlace _nearbyPlaceFromTag(SelectedPlaceTag place) {
    return NearbyPlace(
      id: place.id,
      placeId: place.placeId,
      source: place.source,
      displayName: place.displayName,
      address: place.address,
      category: 'restaurant',
      distanceMeters: 0,
      confidence: 'high',
      coordinates: NearbyPlaceCoordinates(lat: place.lat, lng: place.lng),
      actions: const NearbyPlaceActions(primary: 'select'),
    );
  }

  void _selectPlaceTag(SelectedPlaceTag place) {
    setState(() {
      _selectedPlace = place;
      final exists = _nearbySpots.any((spot) => spot.id == place.id);
      if (!exists) {
        _nearbySpots = [_nearbyPlaceFromTag(place), ..._nearbySpots];
      }
    });
  }

  List<NearbyPlace> _mergeNearbyPlaces(List<NearbyPlace> loadedPlaces) {
    final selectedPlace = _selectedPlace;
    if (selectedPlace == null) return loadedPlaces;

    final exists = loadedPlaces.any((place) => place.id == selectedPlace.id);
    if (exists) return loadedPlaces;

    return [_nearbyPlaceFromTag(selectedPlace), ...loadedPlaces];
  }

  Future<void> _handleSend() async {
    if (_uploadStatus == _UploadStatus.pending) return;

    final selectedPlace = _selectedPlace;
    if (selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn địa điểm trước khi chia sẻ')),
      );
      _showPlacePickerSheet(errorMessage: 'Chọn địa điểm trước khi chia sẻ');
      return;
    }

    setState(() => _uploadStatus = _UploadStatus.pending);

    try {
      final authService = ref.read(authServiceProvider);
      final uploadService = UploadService(authService: authService);
      final source = widget.source;

      await uploadService.upload(
        imagePath: widget.imagePath,
        latitude: selectedPlace.lat,
        longitude: selectedPlace.lng,
        source: source,
      );

      if (mounted) {
        setState(() => _uploadStatus = _UploadStatus.idle);
        Navigator.pushReplacement(
          context,
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const CameraScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (mounted) {
        setState(() => _uploadStatus = _UploadStatus.error);
        final errorMessage = e is UploadException ? e.message : e.toString();
        ErrorDialogs.showUploadError(context, _handleSend, errorMessage: errorMessage);
      }
    }
  }

  void _selectCaption(int index) {
    setState(() {
      _currentIndex = index;
      _isEditingMessage = false;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    Navigator.pop(context); // Close bottom sheet
  }

  void _showPlacePickerSheet({String? errorMessage}) {
    var isLoading = _nearbySpots.isEmpty;
    var places = List<NearbyPlace>.from(_nearbySpots);
    var sheetError = errorMessage;
    var didStartLoad = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!didStartLoad) {
                didStartLoad = true;
                Future<void>(() async {
                  try {
                    final loadedPlaces = _mergeNearbyPlaces(
                      await _fetchNearbySpots(),
                    );
                  if (!mounted) return;
                  setState(() => _nearbySpots = loadedPlaces);
                  setSheetState(() {
                    places = loadedPlaces;
                    isLoading = false;
                  });
                } catch (e) {
                  debugPrint('Error loading nearby spots: $e');
                  setSheetState(() {
                    isLoading = false;
                    sheetError ??= 'Không tải được địa điểm gần đây';
                  });
                }
              });
            }

              return PlacePickerSheetContent(
                places: places,
                isLoading: isLoading,
                errorMessage: sheetError,
                onSelected: (place) {
                  _selectPlaceTag(place);
                  Navigator.pop(context);
                },
              onCreateCustomPlace: _createCustomPlaceTag,
            );
          },
        );
      },
    );
  }

  void _showCaptionBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chú thích',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'General',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 16,
                      children: [
                        _buildBottomSheetPill(
                          icon: 'Aa',
                          label: 'Văn bản',
                          isTextIcon: true,
                          isActive: _currentIndex == 0,
                          onTap: () => _selectCaption(0),
                        ),
                        _buildBottomSheetPill(
                          icon: Icons.access_time_filled_rounded,
                          label: _timeString,
                            isActive: _currentIndex == 1,
                            onTap: () => _selectCaption(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Decorative',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 16,
                      children: [
                        _buildBottomSheetPill(
                          icon: '🪩',
                          label: 'Quẩy thôi!',
                          isEmoji: true,
                          backgroundColor: const Color(0xFFC0FF61),
                          textColor: Colors.black,
                            isActive: _currentIndex == 2,
                            onTap: () => _selectCaption(2),
                        ),
                        _buildBottomSheetPill(
                          icon: '🎆',
                          label: 'Boombayah',
                          isEmoji: true,
                            isActive: _currentIndex == 3,
                            onTap: () => _selectCaption(3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetPill({
    required dynamic icon,
    required String label,
    bool isTextIcon = false,
    bool isEmoji = false,
    Color backgroundColor = const Color(0x1AFFFFFF),
    Color textColor = Colors.white,
    Color? iconColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: isActive ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTextIcon)
              Text(
                icon as String,
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  color: isActive ? Colors.black : textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              )
            else if (isEmoji)
              Text(icon as String, style: const TextStyle(fontSize: 18))
            else
              Icon(
                icon as IconData,
                color: isActive ? Colors.black : (iconColor ?? textColor),
                size: 20,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                color: isActive ? Colors.black : textColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextCaption() {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _isEditingMessage = true),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: _isEditingMessage
                    ? IntrinsicWidth(
                        child: TextField(
                          controller: _messageController,
                          autofocus: true,
                          maxLength: 25,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'SF Pro Text',
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Nhập tin nhắn...',
                            hintStyle: TextStyle(
                              fontFamily: 'SF Pro Text',
                              color: Colors.white60,
                              fontSize: 15,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            counterText: '',
                          ),
                          onSubmitted: (_) =>
                              setState(() => _isEditingMessage = false),
                          onChanged: (_) => setState(() {}),
                        ),
                      )
                    : Text(
                        _messageController.text.isEmpty
                            ? 'Thêm một tin nhắn'
                            : _messageController.text,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Text',
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaticCaption({
    required dynamic icon,
    required String label,
    bool isEmoji = false,
    Color bg = const Color(0x26FFFFFF),
    Color txt = Colors.white,
    Color? icnColor,
  }) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: bg.withValues(alpha: bg.a == 1.0 ? 0.8 : bg.a),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEmoji)
                  Text(icon as String, style: const TextStyle(fontSize: 18))
                else
                  Icon(icon as IconData, color: icnColor ?? txt, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: txt,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Chia sẻ khoảnh khắc',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {},
                          child: const Icon(LucideIcons.download, color: Colors.white54, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                // Image Preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: AspectRatio(
                    aspectRatio: 1 / 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 60,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                          ),

                          // Place tag pill
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Center(
                              child: GestureDetector(
                                onTap: _showPlacePickerSheet,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 260,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEEF0),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.55),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            color: Color(0xFF6A2027),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              _selectedPlace?.displayName ?? 'Chọn địa điểm',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF6A2027),
                                                fontFamily: 'SF Pro',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Caption Carousel
                          Positioned(
                            bottom: 24,
                            left: 0,
                            right: 0,
                            height: 60,
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentIndex = index;
                                  _isEditingMessage = false;
                                });
                              },
                              children: [
                                _buildTextCaption(), // 0: Văn bản
                                _buildStaticCaption(
                                  icon: Icons.access_time_filled_rounded,
                                  label: _timeString,
                                ), // 1: Thời gian
                                _buildStaticCaption(
                                  icon: '🪩',
                                  label: 'Quẩy thôi!',
                                  isEmoji: true,
                                  bg: const Color(
                                    0xFFC0FF61,
                                  ).withValues(alpha: 0.8),
                                  txt: Colors.black,
                                ), // 2: Quẩy thôi
                                _buildStaticCaption(
                                  icon: '🎆',
                                  label: 'Boombayah',
                                  isEmoji: true,
                                ), // 3: Boombayah
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                // "Thêm lời nhắn" button
                GestureDetector(
                  onTap: _showCaptionBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Thêm lời nhắn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Pagination Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _totalCaptions,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: index == _currentIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            PageRouteBuilder<void>(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const CameraScreen(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          ),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Hero(
                          tag: 'capture_to_send_button',
                          child: Material(
                            type: MaterialType.transparency,
                            child: GestureDetector(
                              onTap: _uploadStatus == _UploadStatus.pending
                                  ? null
                                  : _handleSend,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: _uploadStatus == _UploadStatus.error
                                      ? const Color(0xFF8B0000)
                                      : const Color(0xFFEF4050),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: _uploadStatus == _UploadStatus.pending
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          _uploadStatus == _UploadStatus.error
                                              ? 'Lỗi! Thử lại'
                                              : 'Chia sẻ ngay!',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showCaptionBottomSheet,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white54,
                                width: 2,
                              ),
                            ),
                            child: const Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Text(
                                  'Aa',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Text',
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Positioned(
                                  top: -2,
                                  right: -6,
                                  child: Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // "Cùng với" label
                const Text(
                  'Cùng với',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                // Danh sách người nhận
                SizedBox(
                  height: 120,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final friendsState = ref.watch(friendsControllerProvider);
                      final friends = friendsState.friends;

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: friends.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.amber,
                                        width: 2,
                                      ),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[800],
                                      ),
                                      child: const Icon(
                                        Icons.people_alt,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tất cả',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Text',
                                      color: Colors.amber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final friend = friends[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[900],
                                  ),
                                  child: friend.avatarUrl != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(27),
                                          child: Image.network(
                                            friend.avatarUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person,
                                                color: Colors.white54,
                                                size: 24,
                                              );
                                            },
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            friend.initials,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  friend.name,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro Text',
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),

            // Pending upload overlay
            if (_uploadStatus == _UploadStatus.pending)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252020),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFEF484F),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Đang tải lên...',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}













