import 'dart:async';

import 'package:fidee_mobile/screens/ai_chat_screen.dart';
import 'package:fidee_mobile/screens/candidate_feed_screen.dart';
import 'package:fidee_mobile/screens/journey_screen.dart';
import 'package:fidee_mobile/screens/place_details_friends.dart';
import 'package:fidee_mobile/screens/profile_screen.dart';
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
  Timer? _searchDebounce;
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
      // Nearby suggestions are optional for the dashboard entry point.
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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(dashboardControllerProvider.notifier).search(query: value),
    );
  }

  void _submitSearch(String value) {
    _searchDebounce?.cancel();
    ref.read(dashboardControllerProvider.notifier).search(query: value);
  }

  Future<void> _showFilters(DashboardState state) async {
    final result = await showModalBottomSheet<_DashboardFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => _DashboardFilterSheet(state: state),
    );
    if (result == null || !mounted) return;
    await ref
        .read(dashboardControllerProvider.notifier)
        .applyFilters(
          category: result.category,
          priceMax: result.priceMax,
          radius: result.radius,
          sortBy: result.sortBy,
        );
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
          _buildVibeGrid(dashboardState.selectedVibe),
          const SizedBox(height: 28),
          if (dashboardState.isSearchMode)
            _buildSearchResults(dashboardState)
          else ...[
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
                        onChanged: _onSearchChanged,
                        onSubmitted: _submitSearch,
                        textInputAction: TextInputAction.search,
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
                          _submitSearch('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, size: 18),
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
                    state.category != null ||
                        state.priceMax != null ||
                        state.radius != null ||
                        state.sortBy != null
                    ? const Color(0xFFEF484F)
                    : Colors.grey[100],
                foregroundColor:
                    state.category != null ||
                        state.priceMax != null ||
                        state.radius != null ||
                        state.sortBy != null
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
                    .applyFilters(radius: null, sortBy: null),
                child: const Text('Bỏ bộ lọc'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  bool _hasAdvancedFilters(DashboardState state) {
    return state.category != null ||
        state.priceMax != null ||
        state.radius != null ||
        state.sortBy != null;
  }

  String _activeFilterLabel(DashboardState state) {
    final labels = <String>[
      if (state.category != null) state.category!,
      if (state.priceMax != null) '≤ ${_formatPrice(state.priceMax!)}đ',
      if (state.radius != null) '${state.radius! ~/ 1000} km',
      if (state.sortBy == 'distance') 'Gần nhất',
      if (state.sortBy == 'rating') 'Đánh giá',
      if (state.sortBy == 'popular') 'Phổ biến',
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

  Widget _buildVibeGrid(String? selectedVibe) {
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
        final isSelected = selectedVibe == id;

        return GestureDetector(
          onTap: () {
            _searchDebounce?.cancel();
            _searchController.clear();
            setState(() {});
            ref.read(dashboardControllerProvider.notifier).selectVibe(id);
          },
          child: Container(
            width: (MediaQuery.of(context).size.width - 64) / 3,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFFEF484F), Color(0xCCFF1D27)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFDFBFB), Color(0xFFF7C6C7)],
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFEF484F)
                    : const Color(0xFFF7C6C7).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  vibe['icon'] as IconData,
                  color: isSelected ? Colors.white : const Color(0xFFEF484F),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
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

  Widget _buildSearchResults(DashboardState state) {
    final title = state.searchQuery.trim().isNotEmpty
        ? 'Kết quả cho “${state.searchQuery.trim()}”'
        : 'Địa điểm hợp vibe của bạn';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                ref.read(dashboardControllerProvider.notifier).clearSearch();
                setState(() {});
              },
              icon: const Icon(Icons.close, size: 17),
              label: const Text('Xóa lọc'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (state.isSearching && state.searchResults.isEmpty)
          const _DiscoverySearchSkeleton()
        else if (state.searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                'Không tìm thấy địa điểm phù hợp.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          )
        else
          ...state.searchResults.map(_buildSearchPlaceRow),
        if (state.hasMore)
          Center(
            child: TextButton.icon(
              onPressed: state.isLoadingMore
                  ? null
                  : () => ref
                        .read(dashboardControllerProvider.notifier)
                        .loadMore(),
              icon: state.isLoadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Xem thêm'),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchPlaceRow(DashboardPlace place) {
    final tags = <String>[
      place.category,
      ...place.vibes.take(2),
      if (place.priceMax != null) '≤ ${_formatPrice(place.priceMax!)}đ',
    ];
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PlaceDetailsFriends(placeId: place.id),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                place.imageUrl,
                width: 92,
                height: 92,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 92,
                  height: 92,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.storefront),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '★ ${place.rating.toStringAsFixed(1)} · '
                    '${place.distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Color(0xFF6E7E91),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECEF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Color(0xFFEF4050),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).round()}k';
    return value.toString();
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
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
  final String? category;
  final int? priceMax;
  final int? radius;
  final String? sortBy;

  const _DashboardFilterSelection({
    this.category,
    this.priceMax,
    this.radius,
    this.sortBy,
  });
}

class _DashboardFilterSheet extends StatefulWidget {
  final DashboardState state;

  const _DashboardFilterSheet({required this.state});

  @override
  State<_DashboardFilterSheet> createState() => _DashboardFilterSheetState();
}

class _DashboardFilterSheetState extends State<_DashboardFilterSheet> {
  String? _category;
  int? _priceMax;
  int? _radius;
  String? _sortBy;

  @override
  void initState() {
    super.initState();
    _category = widget.state.category;
    _priceMax = widget.state.priceMax;
    _radius = widget.state.radius;
    _sortBy = widget.state.sortBy;
  }

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
            const Text(
              'Lọc địa điểm',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            _label('Loại quán'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ...const <(String, String)>[
                  ('cafe', 'Cà phê'),
                  ('restaurant', 'Nhà hàng'),
                  ('shopping', 'Mua sắm'),
                  ('tourist_attraction', 'Điểm tham quan'),
                ].map((option) {
                  return ChoiceChip(
                    label: Text(option.$2),
                    selected: _category == option.$1,
                    onSelected: (selected) =>
                        setState(() => _category = selected ? option.$1 : null),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
            _label('Mức giá tối đa'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _priceMax == null,
                  onSelected: (_) => setState(() => _priceMax = null),
                ),
                ...const <(int, String)>[
                  (50000, '50k'),
                  (100000, '100k'),
                  (200000, '200k'),
                  (500000, '500k'),
                ].map((option) {
                  return ChoiceChip(
                    label: Text(option.$2),
                    selected: _priceMax == option.$1,
                    onSelected: (selected) =>
                        setState(() => _priceMax = selected ? option.$1 : null),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
            _label('Khoảng cách'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _radius == null,
                  onSelected: (_) => setState(() => _radius = null),
                ),
                ...const <(int, String)>[
                  (1000, '1 km'),
                  (3000, '3 km'),
                  (5000, '5 km'),
                  (10000, '10 km'),
                ].map((option) {
                  return ChoiceChip(
                    label: Text(option.$2),
                    selected: _radius == option.$1,
                    onSelected: (selected) =>
                        setState(() => _radius = selected ? option.$1 : null),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
            _label('Sắp xếp'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _sortBy == null,
                  onSelected: (_) => setState(() => _sortBy = null),
                ),
                ...const <(String, String)>[
                  ('distance', 'Gần nhất'),
                  ('rating', 'Đánh giá'),
                  ('popular', 'Phổ biến'),
                ].map((option) {
                  return ChoiceChip(
                    label: Text(option.$2),
                    selected: _sortBy == option.$1,
                    onSelected: (selected) =>
                        setState(() => _sortBy = selected ? option.$1 : null),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const _DashboardFilterSelection(),
                    ),
                    child: const Text('Đặt lại'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _DashboardFilterSelection(
                        category: _category,
                        priceMax: _priceMax,
                        radius: _radius,
                        sortBy: _sortBy,
                      ),
                    ),
                    icon: const Icon(Icons.tune),
                    label: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DiscoverySearchSkeleton extends StatelessWidget {
  const _DiscoverySearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(double.infinity),
                    const SizedBox(height: 10),
                    _line(150),
                    const SizedBox(height: 10),
                    _line(110),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(double width) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
