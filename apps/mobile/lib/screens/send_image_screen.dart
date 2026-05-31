import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'camera_screen.dart';

class SendImageScreen extends StatefulWidget {
  final String imagePath;
  const SendImageScreen({super.key, required this.imagePath});

  @override
  State<SendImageScreen> createState() => _SendImageScreenState();
}

class _SendImageScreenState extends State<SendImageScreen> {
  final List<String> _friends = ['ahn', 'giang', 'huy', 'linh'];
  
  // Data cho các caption
  String _locationString = 'Đang tải...';
  String _weatherString = 'Đang tải...';
  IconData _weatherIcon = Icons.wb_sunny_rounded;
  Color _weatherColor = Colors.amber;
  String _timeString = '00:00';
  Timer? _clockTimer;
  
  // State cho text pill mặc định
  final TextEditingController _messageController = TextEditingController();
  bool _isEditingMessage = false;

  // Carousel state
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final int _totalCaptions = 6;

  @override
  void initState() {
    super.initState();
    _startClock();
    _fetchLocationAndWeather();
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

  Future<void> _fetchLocationAndWeather() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationString = 'Không có GPS');
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _locationString = 'Từ chối GPS');
          return;
        }
      }
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      
      // Fetch reverse geocoding
      final urlGeo = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json&accept-language=vi');
      final requestGeo = await HttpClient().getUrl(urlGeo);
      requestGeo.headers.set('User-Agent', 'FideeApp/1.0');
      final responseGeo = await requestGeo.close();
      final stringDataGeo = await responseGeo.transform(utf8.decoder).join();
      final jsonGeo = json.decode(stringDataGeo);
      
      if (mounted) {
        setState(() {
          final address = jsonGeo['address'];
          if (address != null) {
            _locationString = (address['city'] ?? address['state'] ?? address['country'] ?? 'Vị trí') as String;
          } else {
            _locationString = 'Vị trí';
          }
        });
      }
      
      // Fetch weather
      final urlWeather = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=weather_code');
      final requestWeather = await HttpClient().getUrl(urlWeather);
      final responseWeather = await requestWeather.close();
      final stringDataWeather = await responseWeather.transform(utf8.decoder).join();
      final jsonWeather = json.decode(stringDataWeather);
      
      final code = jsonWeather['current']['weather_code'] as int;
      _parseWeatherCode(code);
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationString = 'Không rõ';
          _weatherString = 'Không rõ';
        });
      }
    }
  }
  
  void _parseWeatherCode(int code) {
    String text = 'Nhiều mây';
    IconData icon = Icons.cloud_rounded;
    Color color = Colors.white;
    
    if (code == 0) {
      text = 'Trời nắng'; icon = Icons.wb_sunny_rounded; color = Colors.amber;
    } else if (code <= 3) {
      text = 'Nhiều mây'; icon = Icons.cloud_rounded; color = Colors.white;
    } else if (code <= 48) {
      text = 'Có sương mù'; icon = Icons.foggy; color = Colors.white70;
    } else if (code <= 67) {
      text = 'Có mưa'; icon = Icons.water_drop; color = Colors.lightBlueAccent;
    } else if (code <= 77) {
      text = 'Có tuyết'; icon = Icons.ac_unit; color = Colors.white;
    } else if (code <= 99) {
      text = 'Giông bão'; icon = Icons.flash_on; color = Colors.amber;
    }
    
    if (mounted) {
      setState(() {
        _weatherString = text;
        _weatherIcon = icon;
        _weatherColor = color;
      });
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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Chú thích', style: TextStyle(fontFamily: 'SF Pro Text', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('General', style: TextStyle(fontFamily: 'SF Pro Text', color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 16,
                      children: [
                        _buildBottomSheetPill(
                          icon: 'Aa', label: 'Văn bản', isTextIcon: true,
                          isActive: _currentIndex == 0,
                          onTap: () => _selectCaption(0),
                        ),
                        _buildBottomSheetPill(
                          icon: Icons.location_on_rounded, label: _locationString,
                          isActive: _currentIndex == 1,
                          onTap: () => _selectCaption(1),
                        ),
                        _buildBottomSheetPill(
                          icon: _weatherIcon, label: _weatherString,
                          iconColor: _weatherColor, backgroundColor: Colors.blue,
                          isActive: _currentIndex == 2,
                          onTap: () => _selectCaption(2),
                        ),
                        _buildBottomSheetPill(
                          icon: Icons.access_time_filled_rounded, label: _timeString,
                          isActive: _currentIndex == 3,
                          onTap: () => _selectCaption(3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Decorative', style: TextStyle(fontFamily: 'SF Pro Text', color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 16,
                      children: [
                        _buildBottomSheetPill(
                          icon: '🪩', label: 'Quẩy thôi!', isEmoji: true,
                          backgroundColor: const Color(0xFFC0FF61), textColor: Colors.black,
                          isActive: _currentIndex == 4,
                          onTap: () => _selectCaption(4),
                        ),
                        _buildBottomSheetPill(
                          icon: '🎆', label: 'Boombayah', isEmoji: true,
                          isActive: _currentIndex == 5,
                          onTap: () => _selectCaption(5),
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
    required dynamic icon, required String label, bool isTextIcon = false, bool isEmoji = false,
    Color backgroundColor = const Color(0x1AFFFFFF), Color textColor = Colors.white, Color? iconColor,
    required bool isActive, required VoidCallback onTap,
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
              Text(icon as String, style: TextStyle(fontFamily: 'SF Pro Text', color: isActive ? Colors.black : textColor, fontWeight: FontWeight.w700, fontSize: 16))
            else if (isEmoji)
              Text(icon as String, style: const TextStyle(fontSize: 18))
            else
              Icon(icon as IconData, color: isActive ? Colors.black : (iconColor ?? textColor), size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontFamily: 'SF Pro Text', color: isActive ? Colors.black : textColor, fontWeight: FontWeight.w600, fontSize: 15)),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                ),
                child: _isEditingMessage
                    ? IntrinsicWidth(
                        child: TextField(
                          controller: _messageController,
                          autofocus: true,
                          maxLength: 25,
                          maxLines: 1,
                          style: const TextStyle(fontFamily: 'SF Pro Text', color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Nhập tin nhắn...', hintStyle: TextStyle(fontFamily: 'SF Pro Text', color: Colors.white60, fontSize: 15), isDense: true, contentPadding: EdgeInsets.zero, counterText: ''),
                          onSubmitted: (_) => setState(() => _isEditingMessage = false),
                          onChanged: (_) => setState(() {}),
                        ),
                      )
                    : Text(
                        _messageController.text.isEmpty ? 'Thêm một tin nhắn' : _messageController.text,
                        style: const TextStyle(fontFamily: 'SF Pro Text', color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaticCaption({
    required dynamic icon, required String label, bool isEmoji = false,
    Color bg = const Color(0x26FFFFFF), Color txt = Colors.white, Color? icnColor,
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEmoji)
                  Text(icon as String, style: const TextStyle(fontSize: 18))
                else
                  Icon(icon as IconData, color: icnColor ?? txt, size: 20),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontFamily: 'SF Pro Text', color: txt, fontWeight: FontWeight.w600, fontSize: 15)),
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
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Text('Gửi đến...', style: TextStyle(fontFamily: 'SF Pro Text', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[800], child: const Center(child: Icon(Icons.image, size: 60, color: Colors.white54))),
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
                            _buildStaticCaption(icon: Icons.location_on_rounded, label: _locationString), // 1: Vị trí
                            _buildStaticCaption(icon: _weatherIcon, label: _weatherString, icnColor: _weatherColor, bg: Colors.blue.withValues(alpha: 0.6)), // 2: Thời tiết
                            _buildStaticCaption(icon: Icons.access_time_filled_rounded, label: _timeString), // 3: Thời gian
                            _buildStaticCaption(icon: '🪩', label: 'Quẩy thôi!', isEmoji: true, bg: const Color(0xFFC0FF61).withValues(alpha: 0.8), txt: Colors.black), // 4: Quẩy thôi
                            _buildStaticCaption(icon: '🎆', label: 'Boombayah', isEmoji: true), // 5: Boombayah
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(flex: 1),
            // Pagination Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalCaptions, (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3), 
                width: 6, height: 6, 
                decoration: BoxDecoration(color: index == _currentIndex ? Colors.white : Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle)
              )),
            ),
            const SizedBox(height: 24),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          PageRouteBuilder<void>(
                            pageBuilder: (context, animation, secondaryAnimation) => const CameraScreen(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        ),
                        child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 32)),
                      ),
                    ),
                  ),
                  Hero(
                    tag: 'capture_to_send_button',
                    child: Material(
                      type: MaterialType.transparency,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.transparent, width: 0)),
                          child: Center(child: Container(width: 84, height: 84, decoration: const BoxDecoration(color: Color(0xFF333333), shape: BoxShape.circle), child: const Center(child: Icon(Icons.send_rounded, color: Colors.white, size: 36)))),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _showCaptionBottomSheet,
                        child: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle, border: Border.all(color: Colors.white54, width: 2)),
                          child: const Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Text('Aa', style: TextStyle(fontFamily: 'SF Pro Text', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                              Positioned(top: -2, right: -6, child: Icon(Icons.auto_awesome, color: Colors.white, size: 16))
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Danh sách người nhận
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _friends.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Container(
                            width: 54, height: 54,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber, width: 2)),
                            child: Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[800]), child: const Icon(Icons.people_alt, color: Colors.white, size: 24)),
                          ),
                          const SizedBox(height: 6),
                          const Text('Tất cả', style: TextStyle(fontFamily: 'SF Pro Text', color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }
                  final friendName = _friends[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[900]), child: const Icon(Icons.person, color: Colors.white54, size: 24)),
                        const SizedBox(height: 6),
                        Text(friendName, style: const TextStyle(fontFamily: 'SF Pro Text', color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
