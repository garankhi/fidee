import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:native_exif/native_exif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/auth_providers.dart';
import '../services/auth_service.dart';
import '../utils/error.dart';
import 'premium_upgrade_sheet.dart';
import 'send_image_screen.dart';

List<CameraDescription>? globalCameras;

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isFlashOn = false;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _shrinkAnimation;

  @override
  void initState() {
    super.initState();
    _initCamera();

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

  /// Accuracy threshold for camera GPS proof (metres).
  static const double _kGpsAccuracyThreshold = 50.0;

  /// Fetches current GPS position for camera capture proof.
  /// Returns [latitude, longitude] or null on permission/service failure.
  /// Shows [showBadAccuracyError] and returns null if accuracy is poor.
  Future<List<double>?> _captureGpsProof() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ErrorDialogs.showPermissionDeniedError(
            context,
            'Vị trí (GPS đang tắt)',
          );
        }

        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) ErrorDialogs.showPermissionDeniedError(context, 'Vị trí');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (position.accuracy > _kGpsAccuracyThreshold) {
        if (mounted) ErrorDialogs.showBadAccuracyError(context);
        return null;
      }

      return [position.latitude, position.longitude];
    } catch (e) {
      debugPrint('GPS capture error: $e');
      return null;
    }
  }

  Future<void> _initCamera() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
      if (status.isPermanentlyDenied || status.isDenied) {
        if (mounted) ErrorDialogs.showPermissionDeniedError(context, 'Camera');
        return;
      }
    }

    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _setCamera(_selectedCameraIndex);
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
    final isPro = authState?.tier == UserTier.pro;

    if (!isPro) {
      _showProFeatureDialog();
      return;
    }

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

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      _setLoading(true); // Bật loading khi bắt đầu xử lý ảnh
      try {
        final exif = await Exif.fromPath(pickedFile.path);
        final latLong = await exif.getLatLong();
        await exif.close();

        if (latLong == null) {
          _setLoading(false);
          debugPrint('Missing EXIF GPS data');
          if (mounted) ErrorDialogs.showMissingGpsError(context);
          return;
        }

        debugPrint(
          'Tọa độ GPS của ảnh: Lat: ${latLong.latitude}, Lng: ${latLong.longitude}',
        );

        _setLoading(false);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) =>
                SendImageScreen(
                  imagePath: pickedFile.path,
                  // AC2: pass EXIF GPS to preview screen
                  gpsCoordinates: [latLong.latitude, latLong.longitude],
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      } catch (e) {
        _setLoading(false);
        debugPrint('Lỗi đọc EXIF: $e');
        if (mounted) ErrorDialogs.showMissingGpsError(context);
      }
    }
  }

  void _showProFeatureDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumUpgradeSheet(),
    );
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

  @override
  void dispose() {
    _animationController.dispose();
    _controller?.dispose();
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 60.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.map, color: Colors.white, size: 24),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.people, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              '24 người bạn',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
                            'Me',
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
                ),

                const Spacer(flex: 1),

                // Camera Preview (Square, Centered)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: AspectRatio(
                    aspectRatio: 1 / 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_controller!),
                          // Flash Button
                          Positioned(
                            top: 16,
                            left: 16,
                            child: GestureDetector(
                              onTap: _toggleFlash,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          // Zoom Button
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
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),
                const SizedBox(height: 12),

                // Bottom Controls (Gallery, Capture, Flip)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: 24.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Gallery Button
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: SizedBox(
                          width: 55,
                          height: 55,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 5,
                                child: Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDB8787),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 6,
                                top: 8,
                                child: Transform.rotate(
                                  angle: 17 * math.pi / 180,
                                  child: Container(
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E0E0),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Capture Button
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          final shrinkValue = _shrinkAnimation.value;
                          final double currentInnerSize = 68.0 * shrinkValue;

                          return GestureDetector(
                            onTap: () async {
                              if (!_controller!.value.isInitialized ||
                                  _animationController.isAnimating) {
                                return;
                              }

                              final navigator = Navigator.of(context);

                              _animationController.forward();
                              _setLoading(true);

                              final image = await _controller!.takePicture();

                              // AC1: capture GPS proof at shoot time
                              final gpsCoords = await _captureGpsProof();

                              if (_animationController.isAnimating) {
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 500),
                                );
                              }

                              _setLoading(false);

                              if (!mounted) return;
                              navigator.pushReplacement(
                                PageRouteBuilder<void>(
                                  transitionDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => SendImageScreen(
                                        imagePath: image.path,
                                        gpsCoordinates: gpsCoords,
                                      ),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
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
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Flip Camera Button
                      SizedBox(
                        width: 55,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _switchCamera,
                            child: Transform.rotate(
                              angle: -36 * math.pi / 180,
                              child: const Icon(LucideIcons.refreshCcw, color: Colors.white, size: 38),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Section Height Match
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
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[700],
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Lịch sử',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
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
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const Icon(
                              Icons.grid_view_rounded,
                              color: Colors.grey,
                              size: 28,
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.home_filled,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.chat_bubble_rounded,
                                  color: Colors.grey,
                                  size: 28,
                                ),
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text(
                                      '1',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 5,
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: const Color(0x0DFFFFFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        top: 8,
                        child: Transform.rotate(
                          angle: 17 * math.pi / 180,
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: const Color(0x1AFFFFFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                        Icons.grid_view_rounded,
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
