import 'package:fidee_mobile/screens/home_screen.dart';
import 'package:fidee_mobile/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LocationGateScreen extends StatefulWidget {
  final LocationService locationService;

  const LocationGateScreen({super.key, required this.locationService});

  @override
  State<StatefulWidget> createState() => _LocationGateScreenState();
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
      curve: Curves.easeInOut,
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
      await _locationService.refreshPosition();
    } else if (_locationService.status == LocationStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
      await _locationService.initialize();
    } else {
      await _locationService.initialize();
    }

    if (!mounted) return;
    setState(() => _isRequesting = false);
    
    _navigateHome();
  }


  void _navigateHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondary) =>
            HomeScreen(locationService: _locationService),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCEDEE),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Image.asset('assets/images/logo_red.png', height: 28),
              ),

              const Spacer(),

              Image.asset(
                'assets/images/land_spot.png',
                height: 220,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 32),

              const Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 40),
                child: Text(
                  'FIDEE chỉ truy cập vị trí của bạn\nchỉ khi bạn sử dụng ứng dụng',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF646982),
                    fontSize: 18,
                    height: 25 / 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    onTap: _isRequesting ? null : _onAllow,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Cho phép',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            decorationColor: _isRequesting ? Colors.grey : const Color(0xFFEF4050),
                          ),
                        ),

                        const SizedBox(width: 4),

                        const Icon(
                          LucideIcons.arrowRight,
                          color: Color(0xFFEF4050),
                          size: 18,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
