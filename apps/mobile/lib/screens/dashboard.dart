import 'dart:async';

import 'package:fidee_mobile/screens/ai_chat_screen.dart';
import 'package:fidee_mobile/screens/candidate_feed_screen.dart';
import 'package:fidee_mobile/screens/journey_screen.dart';
import 'package:fidee_mobile/screens/place_details_friends.dart';
import 'package:fidee_mobile/screens/profile_screen.dart';
import 'package:fidee_mobile/screens/search_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/dashboard_provider.dart';
import '../models/dashboard_place.dart';
import '../models/nearby_place.dart';
import '../services/nearby_service.dart';
import '../widgets/bottom_nav.dart';
import 'add_spot_screen.dart';

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
    } catch (_) {
    }
  }

  void _onAddSpot() {
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

  void _submitSearch(String value) {
    if (value.trim().isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SearchResultScreen(initialQuery: value.trim()),
      ),
    );
  }

  Future<void> _showFilters(DashboardState state) async {
    final result = await showModalBottomSheet<_DashboardFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => _DashboardFilterSheet(state: state),
    );
    if (result == null || !mounted) return;
    final filterFuture = ref
        .read(dashboardControllerProvider.notifier)
        .applyFilters(
      categories: result.categories,
      priceRanges: result.priceRanges,
      disRanges: result.disRanges,
      sortOptions: result.sortOptions,
    );
    if (result.isEmpty) {
      await filterFuture;
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SearchResultScreen()),
    );
    await filterFuture;
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

  Widget _buildDashboardBody(
      BuildContext context,
      DashboardState dashboardState,
      String? userAvatarUrl,
      ) {
    final places = dashboardState.hotPlaces;
    final friendPlaces = dashboardState.friendActivities;
    final systemPadding = MediaQuery.of(context).padding;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: systemPadding.top > 0 ? systemPadding.top + 10 : 20,
        bottom: systemPadding.bottom > 0 ? systemPadding.bottom + 100 : 110,
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
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.85),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildHeaderSearchBar(dashboardState),
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
          _buildVibeGrid(),
          const SizedBox(height: 28),

          const Text(
            'Đang “hot” 🔥',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildHotPlacesRow(places),
          const SizedBox(height: 28),
          _buildSubSectionHeader('Dành riêng cho bạn'),
          const SizedBox(height: 15),
          _buildHotPlacesRow(dashboardState.recommendedPlaces),
          const SizedBox(height: 28),
          _buildSubSectionHeader('Dựa trên hoạt động của bạn bè'),
          const SizedBox(height: 15),
          _buildFriendsActivityList(friendPlaces),
        ],
      ),
    );
  }

  Widget _buildHeaderSearchBar(DashboardState state) {
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF484F),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Text(
                          'Hỏi AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: _submitSearch,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(color: Colors.black, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Tìm nhà hàng, quán ăn..',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, size: 18, color: Colors.black,),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Lọc địa điểm',
              onPressed: () => _showFilters(state),
              style: IconButton.styleFrom(
                backgroundColor:
                _hasAdvancedFilters(state)
                    ? const Color(0xFFEF484F)
                    : Colors.grey[100],
                foregroundColor:
                _hasAdvancedFilters(state)
                    ? Colors.white
                    : const Color(0xFFEF484F),
              ),
              icon: const Icon(Icons.tune, size: 20),
            ),
          ],
        ),
        if (_hasAdvancedFilters(state)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 16,
                color: Color(0xFFEF484F),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _activeFilterLabel(state),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6E7E91),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref
                    .read(dashboardControllerProvider.notifier)
                    .applyFilters(),
                child: const Text('Bỏ bộ lọc'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  bool _hasAdvancedFilters(DashboardState state) {
    return state.categories.isNotEmpty ||
        state.priceRanges.isNotEmpty ||
        state.disRanges.isNotEmpty ||
        state.sortOptions.isNotEmpty;
  }

  String _activeFilterLabel(DashboardState state) {
    const categoryLabels = <String, String>{
      'cafe': 'Cà phê',
      'restaurant': 'Nhà hàng',
      'hotel': 'Khách sạn',
      'shopping': 'Mua sắm',
      'tourist_attraction': 'Tham quan',
      'office': 'Văn phòng',
      'other': 'Khác',
    };
    const priceLabels = <String, String>{
      '*-50000': 'Dưới 50k',
      '50000-100000': '50k–100k',
      '100000-200000': '100k–200k',
      '200000-500000': '200k–500k',
      '500000-*': 'Trên 500k',
    };
    const distanceLabels = <String, String>{
      '*-1000': 'Dưới 1 km',
      '1000-3000': '1–3 km',
      '3000-5000': '3–5 km',
      '5000-10000': '5–10 km',
      '10000-*': 'Trên 10 km',
    };
    const sortLabels = <String, String>{
      'distance': 'Gần nhất',
      'rating': 'Đánh giá cao',
      'popular': 'Phổ biến',
      'price_asc': 'Giá thấp–cao',
      'price_desc': 'Giá cao–thấp',
      'newest': 'Mới nhất',
    };
    final labels = <String>[
      ...state.categories.map((value) => categoryLabels[value] ?? value),
      ...state.priceRanges.map((value) => priceLabels[value] ?? value),
      ...state.disRanges.map((value) => distanceLabels[value] ?? value),
      ...state.sortOptions.map((value) => sortLabels[value] ?? value),
    ];
    return labels.join(' · ');
  }

  Widget _buildAddPlaceBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7C6C7), Color(0xFFEAE9E8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHƯA TÌM ĐƯỢC QUÁN YÊU THÍCH?',
            style: TextStyle(
              color: Color(0xFFC52128),
              fontSize: 22,
              fontFamily: 'Anton',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hãy thêm địa điểm mới và chia sẻ với mọi người!',
            style: TextStyle(
              color: Color(0xFFEF484F),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _onAddSpot,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildVibeGrid() {
    final vibes = [
      {'id': 'hen_ho', 'title': 'Hẹn hò', 'icon': Icons.favorite},
      {'id': 'nhom_ban', 'title': 'Nhóm bạn', 'icon': Icons.groups},
      {'id': 'hoc_lam_viec', 'title': 'Học/Làm việc', 'icon': Icons.menu_book},
      {'id': 'chill', 'title': 'Chill', 'icon': Icons.nightlight_round},
      {'id': 'lang_man', 'title': 'Lãng mạn', 'icon': Icons.auto_awesome},
      {'id': 'khong_gian_xanh', 'title': 'Không gian xanh', 'icon': Icons.eco},
      {'id': 'acoustic', 'title': 'Acoustic', 'icon': Icons.music_note},
      {'id': 'cafe', 'title': 'Cafe', 'icon': Icons.local_cafe},
      {'id': 'ngot_ngao', 'title': 'Ngọt ngào', 'icon': Icons.cake},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: vibes.map((vibe) {
        final title = vibe['title'] as String;
        final id = vibe['id'] as String;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SearchResultScreen(initialVibe: id),
              ),
            );
          },
          child: Container(
            width: (MediaQuery.of(context).size.width - 64) / 3,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFDFBFB), Color(0xFFF7C6C7)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF7C6C7).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  vibe['icon'] as IconData,
                  color: const Color(0xFFEF484F),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        child: Text(
          'Chưa có địa điểm nổi bật hôm nay.',
          style: TextStyle(color: Colors.grey),
        ),
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
                image: DecorationImage(
                  image: NetworkImage(place.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.85),
                    ],
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${place.rating}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          radius: 15,
                          child: const Icon(
                            Icons.favorite_border,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${place.category} · ${place.distanceKm} km',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${place.friendsCount} bạn đã check-in',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF484F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Check-in',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
        child: Text(
          'Chưa có hoạt động nào từ bạn bè.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
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
                child: Image.network(
                  place.imageUrl,
                  width: 75,
                  height: 75,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${place.category} · ${place.distanceKm}km',
                      style: const TextStyle(
                        color: Color(0xFF8B8B8B),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Minh và ${place.friendsCount} người khác đã ở đây',
                      style: const TextStyle(
                        color: Color(0xFFEF484F),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),
              Column(
                children: [
                  const Text(
                    '5-7 phút',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF484F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Đến quán',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Xem tất cả',
            style: TextStyle(
              color: Color(0xFFEF484F),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardFilterSelection {
  final List<String> categories;
  final List<String> priceRanges;
  final List<String> disRanges;
  final List<String> sortOptions;

  const _DashboardFilterSelection({
    this.categories = const <String>[],
    this.priceRanges = const <String>[],
    this.disRanges = const <String>[],
    this.sortOptions = const <String>[],
  });

  bool get isEmpty =>
      categories.isEmpty &&
      priceRanges.isEmpty &&
      disRanges.isEmpty &&
      sortOptions.isEmpty;
}

class _DashboardFilterSheet extends StatefulWidget {
  final DashboardState state;

  const _DashboardFilterSheet({required this.state});

  @override
  State<_DashboardFilterSheet> createState() => _DashboardFilterSheetState();
}

class _DashboardFilterSheetState extends State<_DashboardFilterSheet> {
  late final Set<String> _categories;
  late final Set<String> _priceRanges;
  late final Set<String> _disRanges;
  late final List<String> _sortOptions;

  @override
  void initState() {
    super.initState();
    _categories = widget.state.categories.toSet();
    _priceRanges = widget.state.priceRanges.toSet();
    _disRanges = widget.state.disRanges.toSet();
    _sortOptions = widget.state.sortOptions.toList();
  }

  // ==========================================
  // BƯỚC 1: THÊM HÀM NÀY VÀO ĐÂY (Ngay trên hàm build)
  // ==========================================
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),

      // Định cấu hình màu nền theo trạng thái dựa trên source code ChoiceChip
      color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFFEF484F); // Selected: Nền đỏ chủ đạo (hoặc màu tuỳ chọn)
        }
        return Colors.grey[200]; // Unselected: Nền xám
      }),

      // Xóa viền đen/xám mặc định của Material 3 để màu xám được phẳng đẹp
      side: const BorderSide(color: Colors.transparent),

      // Cấu hình màu chữ: Selected = Trắng, Unselected = Đen
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),

      // Ẩn dấu check v (nếu muốn giao diện giống tab filter phẳng)
      showCheckmark: false,
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================
  // BƯỚC 2: SỬ DỤNG TRONG HÀM BUILD CỦA BẠN
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lọc địa điểm',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Trả kết quả lọc về màn hình chính
                    Navigator.pop(
                      context,
                      _DashboardFilterSelection(
                        categories: _categories.toList(growable: false),
                        priceRanges: _priceRanges.toList(growable: false),
                        disRanges: _disRanges.toList(growable: false),
                        sortOptions: List<String>.unmodifiable(_sortOptions),
                      ),
                    );
                  },
                  child: const Text(
                    'Áp dụng',
                    style: TextStyle(
                      color: Color(0xFFEF484F),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Loại quán
            _label('Loại quán'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'Tất cả',
                  isSelected: _categories.isEmpty,
                  onSelected: () => setState(_categories.clear),
                ),
                ...const <(String, String)>[
                  ('cafe', 'Cà phê'),
                  ('restaurant', 'Nhà hàng'),
                  ('hotel', 'Khách sạn'),
                  ('shopping', 'Mua sắm'),
                  ('tourist_attraction', 'Điểm tham quan'),
                  ('office', 'Văn phòng'),
                  ('other', 'Khác'),
                ].map((option) {
                  return _buildFilterChip(
                    label: option.$2,
                    isSelected: _categories.contains(option.$1),
                    onSelected: () => setState(() {
                      _categories.contains(option.$1)
                          ? _categories.remove(option.$1)
                          : _categories.add(option.$1);
                    }),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Khoảng giá
            _label('Khoảng giá'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'Tất cả',
                  isSelected: _priceRanges.isEmpty,
                  onSelected: () => setState(_priceRanges.clear),
                ),
                ...const <(String, String)>[
                  ('*-50000', 'Dưới 50k'),
                  ('50000-100000', '50k–100k'),
                  ('100000-200000', '100k–200k'),
                  ('200000-500000', '200k–500k'),
                  ('500000-*', 'Trên 500k'),
                ].map((option) {
                  return _buildFilterChip(
                    label: option.$2,
                    isSelected: _priceRanges.contains(option.$1),
                    onSelected: () => setState(() {
                      _priceRanges.contains(option.$1)
                          ? _priceRanges.remove(option.$1)
                          : _priceRanges.add(option.$1);
                    }),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Khoảng cách
            _label('Khoảng cách'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'Tất cả',
                  isSelected: _disRanges.isEmpty,
                  onSelected: () => setState(_disRanges.clear),
                ),
                ...const <(String, String)>[
                  ('*-1000', 'Dưới 1 km'),
                  ('1000-3000', '1–3 km'),
                  ('3000-5000', '3–5 km'),
                  ('5000-10000', '5–10 km'),
                  ('10000-*', 'Trên 10 km'),
                ].map((option) {
                  return _buildFilterChip(
                    label: option.$2,
                    isSelected: _disRanges.contains(option.$1),
                    onSelected: () => setState(() {
                      _disRanges.contains(option.$1)
                          ? _disRanges.remove(option.$1)
                          : _disRanges.add(option.$1);
                    }),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Sắp xếp (Đã sửa lỗi gõ dở 'Choic' từ file cũ)
            _label('Sắp xếp'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'Mặc định',
                  isSelected: _sortOptions.isEmpty,
                  onSelected: () => setState(_sortOptions.clear),
                ),
                ...const <(String, String)>[
                  ('distance', 'Gần nhất'),
                  ('rating', 'Đánh giá cao'),
                  ('popular', 'Phổ biến'),
                  ('price_asc', 'Giá thấp–cao'),
                  ('price_desc', 'Giá cao–thấp'),
                  ('newest', 'Mới nhất'),
                ].map((option) {
                  return _buildFilterChip(
                    label: option.$2,
                    isSelected: _sortOptions.contains(option.$1),
                    onSelected: () => setState(() {
                      if (_sortOptions.contains(option.$1)) {
                        _sortOptions.remove(option.$1);
                        return;
                      }
                      if (option.$1 == 'price_asc') {
                        _sortOptions.remove('price_desc');
                      } else if (option.$1 == 'price_desc') {
                        _sortOptions.remove('price_asc');
                      }
                      _sortOptions.add(option.$1);
                    }),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
