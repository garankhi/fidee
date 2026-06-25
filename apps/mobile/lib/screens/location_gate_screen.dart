import 'package:flutter/material.dart';

import '../services/location_service.dart';
import 'home_screen.dart';

/// Màn hình gate: hiển thị sau SplashScreen nếu location chưa được cấp phép.
///
/// - Nếu user bật vị trí → initialize lại → vào HomeScreen với full features.
/// - Nếu user bỏ qua → vào HomeScreen với limited mode (chỉ còn AI search).
class LocationGateScreen extends StatefulWidget {
  final LocationService locationService;

  const LocationGateScreen({super.key, required this.locationService});

  @override
  State<LocationGateScreen> createState() => _LocationGateScreenState();
}

class _LocationGateScreenState extends State<LocationGateScreen>
    with SingleTickerProviderStateMixin {
  late final LocationService _locationService;
  bool _isRequesting = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _onAllow() async {
    setState(() => _isRequesting = true);

    if (_locationService.status == LocationStatus.deniedForever) {
      await _locationService.openSettings();
      // Sau khi user quay lại từ Settings, thử refresh
      await _locationService.refreshPosition();
    } else {
      await _locationService.initialize();
    }

    if (!mounted) return;
    setState(() => _isRequesting = false);

    // Dù kết quả thế nào, tiếp tục vào HomeScreen
    // — nếu granted thì full features, còn không thì limited
    _navigateToHome();
  }

  void _onSkip() => _navigateToHome();

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, anim, secondary) =>
            HomeScreen(locationService: _locationService),
        transitionsBuilder: (context, anim, secondary, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isForever = _locationService.status == LocationStatus.deniedForever;
    final isDisabled =
        _locationService.status == LocationStatus.serviceDisabled;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // === ICON ===
                _LocationIllustration(),

                const SizedBox(height: 40),

                // === TITLE ===
                const Text(
                  'Fidey cần biết\nbạn đang ở đâu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 16),

                // === SUBTITLE ===
                Text(
                  isForever
                      ? 'Quyền vị trí bị chặn vĩnh viễn.\nMở Cài đặt để bật lại.'
                      : isDisabled
                      ? 'GPS đang tắt. Bật GPS để dùng đầy đủ tính năng.'
                      : 'Vị trí giúp bạn khám phá quán ăn, check-in\nvà xem quán nổi bật gần bạn.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8B95A1),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 40),

                // === FEATURES LIST ===
                const _FeatureList(locationGranted: false),

                const Spacer(flex: 3),

                // === ALLOW BUTTON ===
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isRequesting ? null : _onAllow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4050),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(
                        0xFFEF4050,
                      ).withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isForever ? 'Mở Cài đặt' : 'Bật vị trí',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                // === SKIP BUTTON ===
                TextButton(
                  onPressed: _isRequesting ? null : _onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8B95A1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Không, tiếp tục với tính năng giới hạn',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// === ILLUSTRATION ===
class _LocationIllustration extends StatefulWidget {
  @override
  State<_LocationIllustration> createState() => _LocationIllustrationState();
}

class _LocationIllustrationState extends State<_LocationIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          Container(
            width: 140 * _pulseAnimation.value,
            height: 140 * _pulseAnimation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFFEF4050,
              ).withValues(alpha: 0.08 * (2 - _pulseAnimation.value)),
            ),
          ),
          // Middle ring
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEF4050).withValues(alpha: 0.12),
            ),
          ),
          // Core
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEF4050).withValues(alpha: 0.18),
            ),
            child: const Center(
              child: Icon(
                Icons.location_on_rounded,
                color: Color(0xFFEF4050),
                size: 38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// === FEATURE COMPARISON LIST ===
class _FeatureList extends StatelessWidget {
  final bool locationGranted;

  const _FeatureList({required this.locationGranted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _FeatureRow(
            icon: Icons.explore_rounded,
            label: 'Khám phá quán gần bạn',
            available: locationGranted,
          ),
          const _Divider(),
          _FeatureRow(
            icon: Icons.camera_alt_rounded,
            label: 'Check-in & chia sẻ địa điểm',
            available: locationGranted,
          ),
          const _Divider(),
          _FeatureRow(
            icon: Icons.people_rounded,
            label: 'Xem bạn bè đang ở đâu',
            available: locationGranted,
          ),
          const _Divider(),
          const _FeatureRow(
            icon: Icons.smart_toy_rounded,
            label: 'Tìm quán bằng AI',
            available: true, // luôn available
            alwaysOn: true,
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool available;
  final bool alwaysOn;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.available,
    this.alwaysOn = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = available ? const Color(0xFF4ADE80) : const Color(0xFF8B95A1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: available ? Colors.white70 : const Color(0xFF4A5568),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: available ? Colors.white : const Color(0xFF4A5568),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (alwaysOn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Luôn bật',
                style: TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Icon(
              available ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: color,
              size: 18,
            ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withValues(alpha: 0.06),
      height: 1,
      thickness: 1,
    );
  }
}
