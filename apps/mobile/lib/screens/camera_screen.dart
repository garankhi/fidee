import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:native_exif/native_exif.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/camera_checkin_feed_provider.dart';
import '../features/auth/chat_provider.dart';
import '../features/auth/friends_provider.dart';
import '../features/friends/widgets/friend_request_widgets.dart';
import '../models/camera_checkin_feed_item.dart';
import '../services/auth_service.dart';
import '../services/camera_startup_permission_flow.dart';
import '../services/friend_service.dart';
import '../services/gallery_asset_picker_service.dart';
import '../services/gallery_permission_service.dart';
import '../services/gallery_preview_service.dart';
import '../utils/error.dart';
import 'camera_audience_selector.dart';
import 'camera_bottom_section.dart';
import 'camera_chat_inbox.dart';
import 'camera_checkin_feed.dart';
import 'camera_feed_message_composer.dart';
import 'camera_friends_sheet.dart';
import 'camera_viewfinder_pager.dart';
import 'gallery_asset_picker_sheet.dart';
import 'gallery_permission_sheet.dart';
import 'gallery_preview_button.dart';
import 'premium_upgrade_sheet.dart';
import 'send_image_screen.dart';

List<CameraDescription>? globalCameras;

const int cameraVideoMaxDurationMs = 3000;

bool canRecordVideo({required bool isPro, required bool cameraReady}) {
  return isPro && cameraReady;
}

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isFlashOn = false;
  bool _isLoading = false;
  late final GalleryPermissionService _galleryPermissionService =
      const GalleryPermissionService();
  late final GalleryPreviewService _galleryPreviewService =
      GalleryPreviewService(permissionService: _galleryPermissionService);
  List<Uint8List> _galleryThumbnails = const <Uint8List>[];
  GalleryPermissionStatus _galleryPermissionStatus =
      GalleryPermissionStatus.notDetermined;
  CameraCheckinFeedItem? _activeFeedItem;
  bool _showFeedAudienceSelector = false;
  bool _showHistoryGrid = false;
  Timer? _recordingTimer;
  bool _isRecordingVideo = false;
  DateTime? _recordingStartedAt;

  late AnimationController _animationController;
  late Animation<double> _shrinkAnimation;

  @override
  void initState() {
    super.initState();
    unawaited(_initCameraAndGalleryPreview());

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _shrinkAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _setLoading(bool value) {
    if (mounted) {
      setState(() {
        _isLoading = value;
      });
    }
  }

  void _handleFeedItemChanged(CameraCheckinFeedItem? item) {
    if (!mounted || item?.id == _activeFeedItem?.id) return;
    setState(() {
      _activeFeedItem = item;
    });
  }

  void _handleFeedModeChanged(bool isViewingFeed) {
    if (_showHistoryGrid && !isViewingFeed) return;
    if (!mounted || _showFeedAudienceSelector == isViewingFeed) return;
    setState(() {
      _showFeedAudienceSelector = isViewingFeed;
    });
  }

  void _openHistoryGrid() {
    if (!mounted) return;
    setState(() {
      _showHistoryGrid = true;
      _showFeedAudienceSelector = true;
      _activeFeedItem = null;
    });
  }

  Future<void> _scrollToFirstStory() async {
    if (_showHistoryGrid) {
      setState(() {
        _showHistoryGrid = false;
        _showFeedAudienceSelector = true;
      });
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openHistoryItem(int index) async {
    if (!mounted) return;
    setState(() {
      _showHistoryGrid = false;
      _showFeedAudienceSelector = true;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      index + 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _selectFeedAudience(CameraFeedAudience audience) async {
    setState(() {
      _activeFeedItem = null;
    });
    await ref
        .read(cameraCheckinFeedControllerProvider.notifier)
        .selectAudience(audience);
  }

  void _recordFeedMessage(String message) {
    final item = _activeFeedItem;
    if (item == null) return;
    debugPrint('Feed reply recorded for ${item.userName}: $message');
  }

  void _recordFeedReaction(String reaction) {
    final item = _activeFeedItem;
    if (item == null) return;
    debugPrint('Feed reaction recorded for ${item.userName}: $reaction');
  }

  void _openChatInbox() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const CameraChatInboxScreen(),
      ),
    );
  }

  Future<void> _loadGalleryPreview() async {
    final result = await _galleryPreviewService.loadRecentThumbnails();
    if (!mounted) return;

    setState(() {
      _galleryPermissionStatus = result.permissionStatus;
      _galleryThumbnails = result.thumbnails;
    });
  }

  Future<void> _initCameraAndGalleryPreview() async {
    final startupFlow = CameraStartupPermissionFlow.live(
      galleryPreviewService: _galleryPreviewService,
    );

    final startupResult = await startupFlow.resolve();
    if (!mounted) return;

    setState(() {
      _galleryPermissionStatus = startupResult.galleryPreview.permissionStatus;
      _galleryThumbnails = startupResult.galleryPreview.thumbnails;
    });

    if (!startupResult.cameraGranted) {
      ErrorDialogs.showPermissionDeniedError(context, 'Camera');
      return;
    }

    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      unawaited(_setCamera(_selectedCameraIndex));
    }
  }

  Future<void> _setCamera(int index) async {
    if (_cameras == null || _cameras!.isEmpty) return;

    final camera = _cameras![index];
    _controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final authState = ref.read(authControllerProvider).valueOrNull;
    var isPro = authState?.tier == UserTier.pro;

    final hasGalleryAccess = await _ensureGalleryPermissionForUpload();
    if (!hasGalleryAccess) return;

    final prefs = await SharedPreferences.getInstance();
    final hideNotice = prefs.getBool('hide_gallery_gps_notice') ?? false;

    if (!hideNotice) {
      if (!mounted) return;
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => const GalleryGpsNoticeDialog(),
      );
      if (shouldContinue != true) return;
    }

    if (!mounted) return;
    final selectedAsset = await showModalBottomSheet<GalleryAssetPickerSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GalleryAssetPickerSheet(
        loadAssets: () => GalleryAssetPickerService(
          permissionService: _galleryPermissionService,
        ).loadRecentMedia(),
      ),
    );

    if (mounted) unawaited(_loadGalleryPreview());
    if (selectedAsset == null) return;

    if (selectedAsset.mediaType == GalleryAssetMediaType.video && !isPro) {
      final upgraded = await _showProFeatureDialog();
      if (!mounted || !upgraded) return;
    }

    await _handleGallerySelection(selectedAsset);
  }

  Future<void> _handleGallerySelection(
    GalleryAssetPickerSelection selectedAsset,
  ) async {
    _setLoading(true);
    try {
      final gpsCoordinates = selectedAsset.mediaType == GalleryAssetMediaType.video
          ? selectedAsset.gpsCoordinates?.toList()
          : await _gpsCoordinatesFromImageExif(selectedAsset.path);

      if (gpsCoordinates == null) {
        _setLoading(false);
        debugPrint('Missing gallery GPS data');
        if (mounted) ErrorDialogs.showMissingGpsError(context);
        return;
      }

      _setLoading(false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              SendImageScreen(
                imagePath: selectedAsset.path,
                source: selectedAsset.source,
                gpsCoordinates: gpsCoordinates,
                durationMs: selectedAsset.durationMs,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      _setLoading(false);
      debugPrint('Lỗi đọc metadata media: $e');
      if (mounted) ErrorDialogs.showMissingGpsError(context);
    }
  }

  Future<List<double>?> _gpsCoordinatesFromImageExif(String imagePath) async {
    final exif = await Exif.fromPath(imagePath);
    try {
      final latLong = await exif.getLatLong();
      if (latLong == null) return null;
      debugPrint(
        'Tọa độ GPS của ảnh: Lat: ${latLong.latitude}, Lng: ${latLong.longitude}',
      );
      return [latLong.latitude, latLong.longitude];
    } finally {
      await exif.close();
    }
  }

  Future<bool> _ensureGalleryPermissionForUpload() async {
    var status = _galleryPermissionStatus;
    status = await _galleryPermissionService.currentStatus();
    if (!mounted) return false;

    setState(() {
      _galleryPermissionStatus = status;
    });

    if (status.hasAccess) return true;

    final action = await showModalBottomSheet<GalleryPermissionAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GalleryPermissionSheet(status: status),
    );

    if (!mounted || action == null || action == GalleryPermissionAction.deny) {
      return false;
    }

    switch (action) {
      case GalleryPermissionAction.requestAccess:
        status = await _galleryPermissionService.requestAccess();
        break;
      case GalleryPermissionAction.selectMore:
        status = await _galleryPermissionService.presentLimitedPicker();
        break;
      case GalleryPermissionAction.openSettings:
        await _galleryPermissionService.openPhotoSettings();
        status = await _galleryPermissionService.currentStatus();
        break;
      case GalleryPermissionAction.deny:
        return false;
    }

    if (!mounted) return false;
    setState(() {
      _galleryPermissionStatus = status;
    });
    await _loadGalleryPreview();

    return status.hasAccess;
  }

  Future<bool> _showProFeatureDialog() async {
    final upgraded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumUpgradeSheet(),
    );
    return upgraded == true;
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    _setCamera(_selectedCameraIndex);
  }

  void _toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    });
  }

  Future<void> _handleCapture() async {
    if (_isRecordingVideo ||
        !_controller!.value.isInitialized ||
        _animationController.isAnimating) {
      return;
    }

    final navigator = Navigator.of(context);

    _animationController.forward();
    _setLoading(true);

    final image = await _controller!.takePicture();

    if (_animationController.isAnimating) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    _setLoading(false);

    if (!mounted) return;
    navigator.pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            SendImageScreen(imagePath: image.path, source: 'IN_APP_CAMERA'),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _startVideoRecording() async {
    var isPro = ref.read(authControllerProvider).valueOrNull?.tier == UserTier.pro;
    final controller = _controller;
    final cameraReady = controller?.value.isInitialized ?? false;

    if (!isPro) {
      final upgraded = await _showProFeatureDialog();
      if (!mounted || !upgraded) return;
      isPro = true;
    }
    if (!canRecordVideo(isPro: isPro, cameraReady: cameraReady) ||
        controller == null ||
        _isRecordingVideo) {
      return;
    }

    try {
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecordingVideo = true;
        _recordingStartedAt = DateTime.now();
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer(
        const Duration(milliseconds: cameraVideoMaxDurationMs),
        () => unawaited(_stopVideoRecording()),
      );
    } catch (error) {
      debugPrint('Start video recording failed: $error');
    }
  }

  Future<void> _stopVideoRecording() async {
    final controller = _controller;
    if (!_isRecordingVideo || controller == null) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final startedAt = _recordingStartedAt;
    final durationMs = startedAt == null
        ? cameraVideoMaxDurationMs
        : math.max(
            1,
            math.min(
              cameraVideoMaxDurationMs,
              DateTime.now().difference(startedAt).inMilliseconds,
            ),
          );

    try {
      final video = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecordingVideo = false;
        _recordingStartedAt = null;
      });
      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              SendImageScreen(
                imagePath: video.path,
                source: 'IN_APP_CAMERA_VIDEO',
                durationMs: durationMs,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (error) {
      debugPrint('Stop video recording failed: $error');
      if (!mounted) return;
      setState(() {
        _isRecordingVideo = false;
        _recordingStartedAt = null;
      });
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _animationController.dispose();
    _controller?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      // Skeleton thay cho spinner fullscreen — giữ layout camera quen thuộc
      // để tránh visual jump khi camera sẵn sàng.
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _CameraSkeleton(),
      );
    }

    final friendsState = ref.watch(friendsControllerProvider);
    final feedState = ref.watch(cameraCheckinFeedControllerProvider);
    final unreadCount = ref.watch(
      chatInboxControllerProvider.select((state) => state.totalUnreadCount),
    );
    final feedController = ref.read(
      cameraCheckinFeedControllerProvider.notifier,
    );
    final authUiState = ref.watch(authControllerProvider).valueOrNull;
    final currentUserInitials = _initialsForName(
      authUiState?.firstName,
      authUiState?.lastName,
      fallback: authUiState?.preferredUsername ?? 'Bạn',
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final deckWidth = math.min(
                  MediaQuery.sizeOf(context).width,
                  460.0,
                );

                return Column(
                  children: [
                    _CameraTopBar(
                      friendsCount: friendsState.friendCount,
                      friendRequestCount: friendsState.requestCount,
                      showAudienceSelector: _showFeedAudienceSelector,
                      selectedAudience: feedState.audience,
                      friends: friendsState.friends,
                      currentUserAvatarUrl: authUiState?.avatarUrl,
                      currentUserInitials: currentUserInitials,
                      onMapTap: () => Navigator.pop(context),
                      onFriendsTap: () => showCameraFriendsSheet(context),
                      onAudienceSelected: (audience) =>
                          unawaited(_selectFeedAudience(audience)),
                    ),
                    Expanded(
                      child: SizedBox(
                        width: _showHistoryGrid
                            ? MediaQuery.sizeOf(context).width
                            : deckWidth,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _showHistoryGrid
                              ? NotificationListener<ScrollNotification>(
                                  key: const ValueKey('camera-history-grid'),
                                  onNotification: (notification) {
                                    if (notification.metrics.pixels >=
                                            notification
                                                    .metrics
                                                    .maxScrollExtent -
                                                280 &&
                                        feedState.hasMore &&
                                        !feedState.isLoadingMore) {
                                      unawaited(feedController.loadMore());
                                    }
                                    return false;
                                  },
                                  child: CameraStoryHistoryGrid(
                                    items: feedState.items,
                                    isLoading: feedState.isLoading,
                                    onItemTap: (index) =>
                                        unawaited(_openHistoryItem(index)),
                                  ),
                                )
                              : CameraViewfinderPager(
                                  key: const ValueKey(
                                    'camera-viewfinder-pager-shell',
                                  ),
                                  pageController: _pageController,
                                  cameraPreview: CameraPreview(_controller!),
                                  cameraOverlay: _CameraPreviewControls(
                                    isFlashOn: _isFlashOn,
                                    onToggleFlash: _toggleFlash,
                                  ),
                                  cameraControls: _CameraCaptureControls(
                                    thumbnails: _galleryThumbnails,
                                    animationController: _animationController,
                                    shrinkAnimation: _shrinkAnimation,
                                    onGalleryTap: _pickFromGallery,
                                    onCapture: _handleCapture,
                                    onStartVideoRecording: _startVideoRecording,
                                    onStopVideoRecording: _stopVideoRecording,
                                    isRecordingVideo: _isRecordingVideo,
                                    onSwitchCamera: _switchCamera,
                                  ),
                                  feedItems: feedState.items,
                                  isFeedLoading: feedState.isLoading,
                                  isFeedLoadingMore: feedState.isLoadingMore,
                                  hasMore: feedState.hasMore,
                                  onLoadMore: feedController.loadMore,
                                  onFeedItemChanged: _handleFeedItemChanged,
                                  onFeedModeChanged: _handleFeedModeChanged,
                                  feedMessageComposerBuilder: (item) =>
                                      CameraFeedMessageComposer(
                                        onSend: _recordFeedMessage,
                                        onReaction: _recordFeedReaction,
                                      ),
                                ),
                        ),
                      ),
                    ),
                    CameraBottomSection(
                      activeTab: _showHistoryGrid
                          ? CameraBottomTab.history
                          : CameraBottomTab.home,
                      showHistory:
                          !_showFeedAudienceSelector && !_showHistoryGrid,
                      unreadCount: unreadCount,
                      onHomeTap: () {
                        if (!_showHistoryGrid) return;
                        setState(() {
                          _showHistoryGrid = false;
                          _showFeedAudienceSelector = false;
                        });
                      },
                      onChatTap: _openChatInbox,
                      onHistoryTap: _openHistoryGrid,
                      onHistoryLabelTap: () =>
                          unawaited(_scrollToFirstStory()),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.6), // Làm mờ nền
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252020),
                    borderRadius: BorderRadius.circular(15),
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
                        'Đang xử lý...',
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
    );
  }
}

String _initialsForName(
  String? firstName,
  String? lastName, {
  required String fallback,
}) {
  final first = firstName?.trim();
  final last = lastName?.trim();
  if (first != null && first.isNotEmpty) {
    final firstLetter = first.characters.first.toUpperCase();
    final lastLetter = last == null || last.isEmpty
        ? ''
        : last.characters.first.toUpperCase();
    return '$firstLetter$lastLetter';
  }

  final normalizedFallback = fallback.trim();
  if (normalizedFallback.isEmpty) return 'B';
  return normalizedFallback.characters.first.toUpperCase();
}

class _CameraTopBar extends StatelessWidget {
  final int friendsCount;
  final int friendRequestCount;
  final bool showAudienceSelector;
  final CameraFeedAudience selectedAudience;
  final List<FriendProfile> friends;
  final String? currentUserAvatarUrl;
  final String currentUserInitials;
  final VoidCallback onMapTap;
  final VoidCallback onFriendsTap;
  final ValueChanged<CameraFeedAudience> onAudienceSelected;

  const _CameraTopBar({
    required this.friendsCount,
    required this.friendRequestCount,
    required this.showAudienceSelector,
    required this.selectedAudience,
    required this.friends,
    required this.currentUserAvatarUrl,
    required this.currentUserInitials,
    required this.onMapTap,
    required this.onFriendsTap,
    required this.onAudienceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 60.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onMapTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.map, color: Colors.white, size: 24),
            ),
          ),
          showAudienceSelector
              ? CameraAudienceSelector(
                  selectedAudience: selectedAudience,
                  friends: friends,
                  currentUserAvatarUrl: currentUserAvatarUrl,
                  currentUserInitials: currentUserInitials,
                  onSelected: onAudienceSelected,
                )
              : _FriendsCountPill(
                  count: friendsCount,
                  requestCount: friendRequestCount,
                  onTap: onFriendsTap,
                ),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'Tôi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPreviewControls extends StatelessWidget {
  final bool isFlashOn;
  final VoidCallback onToggleFlash;

  const _CameraPreviewControls({
    required this.isFlashOn,
    required this.onToggleFlash,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: onToggleFlash,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Text(
              '1x',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraCaptureControls extends StatelessWidget {
  final List<Uint8List> thumbnails;
  final AnimationController animationController;
  final Animation<double> shrinkAnimation;
  final VoidCallback onGalleryTap;
  final Future<void> Function() onCapture;
  final Future<void> Function() onStartVideoRecording;
  final Future<void> Function() onStopVideoRecording;
  final bool isRecordingVideo;
  final VoidCallback onSwitchCamera;

  const _CameraCaptureControls({
    required this.thumbnails,
    required this.animationController,
    required this.shrinkAnimation,
    required this.onGalleryTap,
    required this.onCapture,
    required this.onStartVideoRecording,
    required this.onStopVideoRecording,
    required this.isRecordingVideo,
    required this.onSwitchCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GalleryPreviewButton(thumbnails: thumbnails, onTap: onGalleryTap),
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              final shrinkValue = shrinkAnimation.value;
              final currentInnerSize = isRecordingVideo ? 48.0 : 68.0 * shrinkValue;

              return GestureDetector(
                onTap: () => unawaited(onCapture()),
                onLongPressStart: (_) => unawaited(onStartVideoRecording()),
                onLongPressEnd: (_) => unawaited(onStopVideoRecording()),
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF484F),
                      width: 5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: currentInnerSize,
                      height: currentInnerSize,
                      decoration: BoxDecoration(
                        color: isRecordingVideo
                            ? const Color(0xFFEF484F)
                            : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(
            width: 55,
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onSwitchCamera,
                child: Transform.rotate(
                  angle: -36 * math.pi / 180,
                  child: const Icon(
                    LucideIcons.refreshCcw,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsCountPill extends StatelessWidget {
  final int count;
  final int requestCount;
  final VoidCallback onTap;

  const _FriendsCountPill({
    required this.count,
    required this.requestCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  '$count người bạn',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: FriendRequestBadge(count: requestCount),
          ),
        ],
      ),
    );
  }
}

class GalleryGpsNoticeDialog extends StatefulWidget {
  const GalleryGpsNoticeDialog({super.key});

  @override
  State<GalleryGpsNoticeDialog> createState() => _GalleryGpsNoticeDialogState();
}

class _GalleryGpsNoticeDialogState extends State<GalleryGpsNoticeDialog> {
  bool _dontShowAgain = false;

  void _onContinue() async {
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hide_gallery_gps_notice', true);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF252020),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Lưu ý về vị trí',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ảnh tải lên từ thư viện bắt buộc phải được bật Vị trí (GPS) lúc chụp để xác thực điểm check-in.',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'SF Pro',
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Theme(
            data: Theme.of(
              context,
            ).copyWith(unselectedWidgetColor: Colors.white54),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: const Color(0xFFEF484F),
              title: const Text(
                'Không hiện lại',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'SF Pro',
                  fontSize: 15,
                ),
              ),
              value: _dontShowAgain,
              onChanged: (value) {
                setState(() {
                  _dontShowAgain = value ?? false;
                });
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Hủy',
            style: TextStyle(color: Colors.white54, fontFamily: 'SF Pro'),
          ),
        ),
        ElevatedButton(
          onPressed: _onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF484F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            'Tiếp tục',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraSkeleton extends StatelessWidget {
  const _CameraSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Top Bar Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 60.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Map button placeholder
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0x1AFFFFFF), // 10% white
                    shape: BoxShape.circle,
                  ),
                ),
                // Friends pill placeholder
                Container(
                  width: 130,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                // Profile button placeholder
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0x1AFFFFFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 1),

          // Camera Viewfinder Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: AspectRatio(
              aspectRatio: 1 / 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x0DFFFFFF), // 5% white
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
                ),
                child: const Center(
                  child: Icon(
                    Icons.photo_camera,
                    color: Color(0x33FFFFFF), // 20% white
                    size: 48,
                  ),
                ),
              ),
            ),
          ),

          const Spacer(flex: 1),
          const SizedBox(height: 12),

          // Bottom Controls Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 40.0,
              vertical: 24.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Gallery placeholder
                SizedBox(
                  width: 55,
                  height: 55,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: const Color(0x1FFFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x2EFFFFFF)),
                      ),
                      child: const Icon(
                        Icons.photo_library_outlined,
                        color: Color(0xB3FFFFFF),
                        size: 24,
                      ),
                    ),
                  ),
                ),

                // Capture Button placeholder
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x1AFFFFFF),
                      width: 5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: Color(0x33FFFFFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

                // Flip button placeholder
                SizedBox(
                  width: 55,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0x1AFFFFFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar Placeholders
          SizedBox(
            height: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x1AFFFFFF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 60,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0x33FFFFFF),
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.only(left: 110, right: 110),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x0DFFFFFF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: Color(0x33FFFFFF),
                        size: 28,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0x1AFFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.home_filled,
                          color: Color(0x33FFFFFF),
                          size: 24,
                        ),
                      ),
                      const Icon(
                        Icons.chat_bubble_rounded,
                        color: Color(0x33FFFFFF),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
