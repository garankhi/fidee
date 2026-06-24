import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/camera_checkin_feed_provider.dart';
import '../features/auth/chat_provider.dart';
import '../features/auth/friends_provider.dart';
import '../features/friends/widgets/friend_request_widgets.dart';
import '../models/camera_checkin_feed_item.dart';
import '../services/friend_service.dart';
import '../utils/error.dart';
import 'camera_audience_selector.dart';
import 'camera_bottom_section.dart';
import 'camera_chat_inbox.dart';
import 'camera_checkin_feed.dart';
import 'camera_feed_message_composer.dart';
import 'camera_friends_sheet.dart';
import 'camera_viewfinder_pager.dart';
import 'profile_screen.dart';
import 'send_image_screen.dart';

List<CameraDescription>? globalCameras;

const int cameraVideoMaxDurationMs = 3000;
const double _cameraBaseZoomLevel = 1.0;
const double _cameraZoomedLevel = 1.5;

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
  double _zoomLevel = _cameraBaseZoomLevel;
  CameraCheckinFeedItem? _activeFeedItem;
  bool _showFeedAudienceSelector = false;
  CameraBottomTab _activeBottomTab = CameraBottomTab.home;
  final bool _isRecordingVideo = false;
  // Timer? _recordingTimer;
  // DateTime? _recordingStartedAt;

  late AnimationController _animationController;
  late Animation<double> _shrinkAnimation;

  @override
  void initState() {
    super.initState();
    unawaited(_initCamera());

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
    if (_activeBottomTab != CameraBottomTab.home) return;
    if (!mounted || _showFeedAudienceSelector == isViewingFeed) return;
    setState(() {
      _showFeedAudienceSelector = isViewingFeed;
    });
  }

  void _openHistoryGrid() {
    if (!mounted) return;
    setState(() {
      _activeBottomTab = CameraBottomTab.history;
      _showFeedAudienceSelector = true;
      _activeFeedItem = null;
    });
  }

  void _openHomeTab() {
    if (!mounted) return;

    if (_activeBottomTab == CameraBottomTab.home) {
      unawaited(_returnToCameraPage());
      return;
    }

    setState(() {
      _activeBottomTab = CameraBottomTab.home;
      _showFeedAudienceSelector = false;
      _activeFeedItem = null;
    });
    unawaited(_returnToCameraPage());
  }

  Future<void> _returnToCameraPage() async {
    if (!mounted) return;

    setState(() {
      _showFeedAudienceSelector = false;
      _activeFeedItem = null;
    });

    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _openChatTab() {
    if (!mounted || _activeBottomTab == CameraBottomTab.chat) return;
    setState(() {
      _activeBottomTab = CameraBottomTab.chat;
      _showFeedAudienceSelector = false;
      _activeFeedItem = null;
    });
  }

  Future<void> _scrollToFirstStory() async {
    if (_activeBottomTab == CameraBottomTab.history) {
      setState(() {
        _activeBottomTab = CameraBottomTab.home;
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
      _activeBottomTab = CameraBottomTab.home;
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

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const ProfileScreen()),
    );
  }

  Future<void> _initCamera() async {
    var cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      cameraStatus = await Permission.camera.request();
    }

    if (!mounted) return;

    if (!cameraStatus.isGranted && !cameraStatus.isLimited) {
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
    final controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
    );
    _controller = controller;

    try {
      await controller.initialize();
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final baseZoom = _cameraBaseZoomLevel.clamp(minZoom, maxZoom).toDouble();
      await controller.setZoomLevel(baseZoom);
      if (!mounted) return;
      setState(() {
        _zoomLevel = baseZoom;
      });
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  // Upload ảnh từ thư viện đang được tắt ở camera screen.

  // MVP publish: Pro/payment upgrade UI is hidden until subscriptions return.
  // Future<bool> _showProFeatureDialog() async {
  //   final upgraded = await showModalBottomSheet<bool>(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => const PremiumUpgradeSheet(),
  //   );
  //   return upgraded == true;
  // }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    setState(() {
      _zoomLevel = _cameraBaseZoomLevel;
    });
    unawaited(_setCamera(_selectedCameraIndex));
  }

  void _toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    });
  }

  Future<void> _toggleZoom() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final nextZoom = _zoomLevel >= _cameraZoomedLevel
        ? _cameraBaseZoomLevel
        : _cameraZoomedLevel;

    try {
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final clampedZoom = nextZoom.clamp(minZoom, maxZoom).toDouble();
      await controller.setZoomLevel(clampedZoom);
      if (!mounted) return;
      setState(() {
        _zoomLevel = clampedZoom;
      });
    } catch (e) {
      debugPrint('Camera zoom error: $e');
    }
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

  // MVP publish: long-press video recording is disabled.
  // Future<void> _startVideoRecording() { ... }
  // Future<void> _stopVideoRecording() async { ... }

  @override
  void dispose() {
    // MVP publish: video recording timer is dormant with video disabled.
    // _recordingTimer?.cancel();
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
    const chatBackgroundColor = Color(0xFF101B1F);
    final isChatTab = _activeBottomTab == CameraBottomTab.chat;

    return Scaffold(
      backgroundColor: isChatTab ? chatBackgroundColor : Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final deckWidth = math.min(
                  MediaQuery.sizeOf(context).width,
                  460.0,
                );
                final isHistoryTab =
                    _activeBottomTab == CameraBottomTab.history;

                return Column(
                  children: [
                    if (!isChatTab)
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
                        onProfileTap: _openProfile,
                        onAudienceSelected: (audience) =>
                            unawaited(_selectFeedAudience(audience)),
                      ),
                    Expanded(
                      child: SizedBox(
                        width: isHistoryTab || isChatTab
                            ? MediaQuery.sizeOf(context).width
                            : deckWidth,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: isHistoryTab
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
                              : isChatTab
                              ? const ColoredBox(
                                  key: ValueKey('camera-chat-tab'),
                                  color: chatBackgroundColor,
                                  child: CameraChatInboxContent(),
                                )
                              : CameraViewfinderPager(
                                  key: const ValueKey(
                                    'camera-viewfinder-pager-shell',
                                  ),
                                  pageController: _pageController,
                                  cameraPreview: _NonDistortingCameraPreview(
                                    controller: _controller!,
                                  ),
                                  cameraOverlay: _CameraPreviewControls(
                                    isFlashOn: _isFlashOn,
                                    zoomLevel: _zoomLevel,
                                    onToggleFlash: _toggleFlash,
                                    onToggleZoom: () =>
                                        unawaited(_toggleZoom()),
                                  ),
                                  cameraControls: _CameraCaptureControls(
                                    animationController: _animationController,
                                    shrinkAnimation: _shrinkAnimation,
                                    onCapture: _handleCapture,
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
                      activeTab: _activeBottomTab,
                      showHistory:
                          !_showFeedAudienceSelector &&
                          _activeBottomTab == CameraBottomTab.home,
                      showHomeAsShutter:
                          _showFeedAudienceSelector &&
                          _activeBottomTab == CameraBottomTab.home,
                      unreadCount: unreadCount,
                      onHomeTap: _openHomeTab,
                      onChatTap: _openChatTab,
                      onHistoryTap: _openHistoryGrid,
                      onHistoryLabelTap: () => unawaited(_scrollToFirstStory()),
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
  final VoidCallback onProfileTap;
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
    required this.onProfileTap,
    required this.onAudienceSelected,
  });

  @override
  Widget build(BuildContext context) {
    final compactHeight = MediaQuery.sizeOf(context).height < 720;
    final avatarUrl = currentUserAvatarUrl?.trim();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: compactHeight ? 24.0 : 44.0,
      ),
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
          GestureDetector(
            key: const ValueKey('camera-profile-button'),
            onTap: onProfileTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? _CameraProfileInitials(initials: currentUserInitials)
                  : Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _CameraProfileInitials(initials: currentUserInitials),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraProfileInitials extends StatelessWidget {
  final String initials;

  const _CameraProfileInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.blueAccent,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CameraPreviewControls extends StatelessWidget {
  final bool isFlashOn;
  final double zoomLevel;
  final VoidCallback onToggleFlash;
  final VoidCallback onToggleZoom;

  const _CameraPreviewControls({
    required this.isFlashOn,
    required this.zoomLevel,
    required this.onToggleFlash,
    required this.onToggleZoom,
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
          child: GestureDetector(
            onTap: onToggleZoom,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Text(
                zoomLevel >= _cameraZoomedLevel - 0.01 ? '1.5x' : '1x',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NonDistortingCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _NonDistortingCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final previewWidth = isPortrait ? previewSize.height : previewSize.width;
    final previewHeight = isPortrait ? previewSize.width : previewSize.height;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CameraCaptureControls extends StatelessWidget {
  final AnimationController animationController;
  final Animation<double> shrinkAnimation;
  final Future<void> Function() onCapture;
  final bool isRecordingVideo;
  final VoidCallback onSwitchCamera;

  const _CameraCaptureControls({
    required this.animationController,
    required this.shrinkAnimation,
    required this.onCapture,
    required this.isRecordingVideo,
    required this.onSwitchCamera,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactWidth = constraints.maxWidth < 360;
        final captureOuterSize = compactWidth ? 78.0 : 86.0;
        final captureInnerBaseSize = compactWidth ? 60.0 : 68.0;

        return SafeArea(
          top: false,
          minimum: EdgeInsets.only(bottom: compactWidth ? 8 : 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compactWidth ? 16.0 : 24.0,
                  vertical: compactWidth ? 12.0 : 18.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 55),
                    AnimatedBuilder(
                      animation: animationController,
                      builder: (context, child) {
                        final shrinkValue = shrinkAnimation.value;
                        final currentInnerSize = isRecordingVideo
                            ? 48.0
                            : captureInnerBaseSize * shrinkValue;

                        return GestureDetector(
                          onTap: () => unawaited(onCapture()),
                          // MVP publish: video recording is hidden/disabled.
                          // onLongPressStart: (_) =>
                          //     unawaited(onStartVideoRecording()),
                          // onLongPressEnd: (_) =>
                          //     unawaited(onStopVideoRecording()),
                          child: Container(
                            width: captureOuterSize,
                            height: captureOuterSize,
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
              ),
            ),
          ),
        );
      },
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

class _CameraSkeleton extends StatelessWidget {
  const _CameraSkeleton();

  @override
  Widget build(BuildContext context) {
    final compactHeight = MediaQuery.sizeOf(context).height < 720;

    return SafeArea(
      child: Column(
        children: [
          // Top Bar Placeholder
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: compactHeight ? 24.0 : 44.0,
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

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const targetAspectRatio = 1.0;
                const horizontalPadding = 16.0;
                final controlsHeight = compactHeight ? 104.0 : 122.0;
                final frameMaxHeight = math.max(
                  0.0,
                  constraints.maxHeight - controlsHeight - 10,
                );
                final frameWidth =
                    (constraints.maxWidth - horizontalPadding * 2).clamp(
                      0.0,
                      frameMaxHeight * targetAspectRatio,
                    );
                final frameHeight = frameWidth / targetAspectRatio;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: frameWidth,
                            height: frameHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0x0DFFFFFF),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: const Color(0x1AFFFFFF),
                                  width: 1,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.photo_camera,
                                  color: Color(0x33FFFFFF),
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compactHeight ? 10 : 16),
                      SizedBox(
                        height: controlsHeight,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(width: 55),
                                Container(
                                  width: compactHeight ? 78 : 86,
                                  height: compactHeight ? 78 : 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0x1AFFFFFF),
                                      width: 5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: compactHeight ? 60 : 68,
                                      height: compactHeight ? 60 : 68,
                                      decoration: const BoxDecoration(
                                        color: Color(0x33FFFFFF),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
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
                        ),
                      ),
                    ],
                  ),
                );
              },
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
