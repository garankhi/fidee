import 'package:fidee_mobile/screens/place_details_friends.dart';
import 'package:fidee_mobile/screens/candidate_feed_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fidee_mobile/screens/ai_chat_screen.dart';
import 'package:fidee_mobile/screens/profile_screen.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/dashboard_provider.dart';
import '../models/dashboard_place.dart';
import '../models/nearby_place.dart';
import '../services/nearby_service.dart';
import '../widgets/bottom_nav.dart';
import 'add_spot_screen.dart';
import 'journey_screen.dart';
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<NearbyPlace> _nearbySpots = [];
  final TextEditingController _searchController = TextEditingController();
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadNearbySpots();
  }

  Future<void> _loadNearbySpots() async {
    try {
      final authService = ref.read(authServiceProvider);
      final nearbyService = NearbyService(authService);
      final res = await nearbyService.fetchNearby(
        lat: 10.762892,
        lng: 106.682586,
        mediaId: 'explore_${DateTime.now().millisecondsSinceEpoch}',
      );
      setState(() {
        _nearbySpots = res.data.where((p) => !p.isCustomFallback).toList();
      });
    } catch (e) {
    }
  }

  void _onAddSpot() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AddSpotScreen(
          spotSuggestions: _nearbySpots,
          authService: ref.read(authServiceProvider),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final userAvatarUrl = authState?.avatarUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: false,

      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildDashboardBody(context, dashboardState, userAvatarUrl),
          const CandidateFeedScreen(),
          const JourneyScreen(),
          const ProfileScreen(),
        ],
      ),

      bottomNavigationBar: BottomNav(
        currentIndex: _currentNavIndex,
        userAvatarUrl: userAvatarUrl,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildDashboardBody(BuildContext context, dynamic dashboardState, String? userAvatarUrl) {
    final places = dashboardState.hotPlaces;
    final friendPlaces = dashboardState.friendActivities;
    final systemPadding = MediaQuery.of(context).padding;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: systemPadding.top > 0 ? systemPadding.top + 10 : 20,
       bottom: 30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hôm nay ăn gì cho hợp “vibe”?',
                  style: TextStyle(color: Colors.black.withOpacity(0.85), fontSize: 20, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildHeaderSearchBar(),
          const SizedBox(height: 25),
          _buildAddPlaceBanner(),
          const SizedBox(height: 25),

          const Text(
            '“Vibe” hôm nay là gì?',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildVibeGrid(dashboardState.selectedVibe as String?),
          const SizedBox(height: 28),

          const Text(
            'Đang “hot” 🔥',
            style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          _buildHotPlacesRow(places as List<DashboardPlace>),
          const SizedBox(height: 28),

          _buildSubSectionHeader('Dành riêng cho bạn'),
          const SizedBox(height: 15),
          _buildHotPlacesRow(dashboardState.recommendedPlaces as List<DashboardPlace>),
          const SizedBox(height: 28),

          _buildSubSectionHeader('Dựa trên hoạt động của bạn bè'),
          const SizedBox(height: 15),
          _buildFriendsActivityList(friendPlaces as List<DashboardPlace>),
        ],
      ),
    );
  }

  Widget _buildHeaderSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AiChatScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF484F),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            'Hỏi AI',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Tìm nhà hàng, quán ăn..',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ]
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 36,
              width: 46,
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!)),
              child: const Icon(Icons.tune, color: Color(0xFFEF484F), size: 20),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildAddPlaceBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF7C6C7), Color(0xFFEAE9E8)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHƯA TÌM ĐƯỢC QUÁN YÊU THÍCH?',
            style: TextStyle(color: Color(0xFFC52128), fontSize: 22, fontFamily: 'Anton', fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hãy thêm địa điểm mới và chia sẻ với mọi người!',
            style: TextStyle(color: Color(0xFFEF484F), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _onAddSpot,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4050),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4050).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'Thêm ngay vào bản đồ!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVibeGrid(String? selectedVibe) {
    final vibes = [
      {'title': 'Hẹn hò', 'icon': Icons.favorite},
      {'title': 'Nhóm bạn', 'icon': Icons.groups},
      {'title': 'Học/Làm việc', 'icon': Icons.menu_book},
      {'title': 'Chill', 'icon': Icons.nightlight_round},
      {'title': 'Lãng mạn', 'icon': Icons.auto_awesome},
      {'title': 'Không gian xanh', 'icon': Icons.eco},
      {'title': 'Acoustic', 'icon': Icons.music_note},
      {'title': 'Cafe', 'icon': Icons.local_cafe},
      {'title': 'Ngọt ngào', 'icon': Icons.cake},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: vibes.map((vibe) {
        final title = vibe['title'] as String;
        final isSelected = selectedVibe == title;

        return GestureDetector(
          onTap: () => ref.read(dashboardControllerProvider.notifier).selectVibe(title),
          child: Container(
            width: (MediaQuery.of(context).size.width - 64) / 3,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(colors: [Color(0xFFEF484F), Color(0xCCFF1D27)])
                  : const LinearGradient(colors: [Color(0xFFFDFBFB), Color(0xFFF7C6C7)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? const Color(0xFFEF484F) : const Color(0xFFF7C6C7).withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Icon(vibe['icon'] as IconData, color: isSelected ? Colors.white : const Color(0xFFEF484F), size: 26),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w600),
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHotPlacesRow(List<DashboardPlace> places) {
    if (places.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('Chưa có địa điểm nổi bật hôm nay.', style: TextStyle(color: Colors.grey)),
      );
    }

    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: places.length,
        itemBuilder: (context, index) {
          final place = places[index];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PlaceDetailsFriends(placeId: place.id),
                ),
              );
            },
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(right: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(image: NetworkImage(place.imageUrl), fit: BoxFit.cover),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.85)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              const SizedBox(width: 3),
                              Text('${place.rating}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          radius: 15,
                          child: const Icon(Icons.favorite_border, color: Colors.white, size: 14),
                        )
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('${place.category} · ${place.distanceKm} km', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${place.friendsCount} bạn đã check-in', style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFEF484F), borderRadius: BorderRadius.circular(12)),
                              child: const Text('Check-in', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFriendsActivityList(List<DashboardPlace> places) {
    if (places.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('Chưa có hoạt động nào từ bạn bè.', style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    return Column(
      children: places.take(3).map((place) {
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(place.imageUrl, width: 75, height: 75, fit: BoxFit.cover),
              ),
              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(color: Color(0xFF1E1E1E), fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('${place.category} · ${place.distanceKm}km', style: const TextStyle(color: Color(0xFF8B8B8B), fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(
                      'Minh và ${place.friendsCount} người khác đã ở đây',
                      style: const TextStyle(color: Color(0xFFEF484F), fontSize: 12, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),
              Column(
                children: [
                  const Text('5-7 phút', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFEF484F), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Đến quán', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ],
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: () {}, child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFFEF484F), fontSize: 13, fontWeight: FontWeight.w600)))
      ],
    );
  }
}