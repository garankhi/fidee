import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import '../services/discovery_feed_service.dart';
import '../services/place_search_service.dart';
import 'add_spot_screen.dart';
import 'ai_chat_screen.dart';
import 'place_details_friends.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  DiscoveryFeedData _feed = DiscoveryFeedData.empty();
  List<DiscoveryPlace>? _searchResults;
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFeed());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    final location = ref.read(locationControllerProvider).valueOrNull;
    final service = DiscoveryFeedService(ref.read(authServiceProvider));
    final feed = await service.fetchFeed(
      lat: location?.currentPosition.latitude ?? 10.7769,
      lng: location?.currentPosition.longitude ?? 106.7009,
    );
    if (!mounted) return;
    setState(() {
      _feed = feed;
      _isLoading = false;
    });
  }

  Future<void> _search() async {
    final prompt = _searchController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _searchResults = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await const PlaceSearchService().search(prompt);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Chưa thể tìm kiếm lúc này. Hãy thử lại sau.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _openPlace(DiscoveryPlace place) {
    if (place.isCandidate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Địa điểm này đang chờ được xác minh.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlaceDetailsFriends(placeId: place.placeId),
      ),
    );
  }

  void _openAddSpot() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AddSpotScreen(
          spotSuggestions: const [],
          authService: ref.read(authServiceProvider),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFEF4050),
          onRefresh: _loadFeed,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                sliver: SliverList.list(
                  children: [
                    _Header(onBack: () => Navigator.pop(context)),
                    const SizedBox(height: 18),
                    const Text(
                      'Hôm nay ăn gì cho hợp “vibe”?',
                      style: TextStyle(
                        color: Color(0xFF171717),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SearchBar(
                      controller: _searchController,
                      isLoading: _isSearching,
                      onSubmitted: (_) => _search(),
                      onAiTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AiChatScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _AddPlaceBanner(onTap: _openAddSpot),
                    const SizedBox(height: 24),
                    const _WeatherCard(),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: '“Vibe” hôm nay là gì?'),
                    const SizedBox(height: 14),
                    const _VibeGrid(),
                    const SizedBox(height: 28),
                    if (_error != null) _MessageCard(message: _error!),
                    if (_searchResults != null) ...[
                      _SectionTitle(
                        title: 'Kết quả tìm kiếm',
                        trailing: '${_searchResults!.length} địa điểm',
                      ),
                      const SizedBox(height: 14),
                      _PlaceList(
                        places: _searchResults!,
                        onTap: _openPlace,
                        emptyMessage: 'Không tìm thấy địa điểm phù hợp.',
                      ),
                    ] else if (_isLoading) ...[
                      const _SectionTitle(title: 'Đang “hot” 🔥'),
                      const SizedBox(height: 14),
                      const _PlaceSkeleton(),
                    ] else ...[
                      _FeedSection(
                        title: 'Đang “hot” 🔥',
                        places: _feed.hotPlaces,
                        onTap: _openPlace,
                      ),
                      _FeedSection(
                        title: 'Dành riêng cho bạn',
                        places: _feed.recommendedPlaces,
                        onTap: _openPlace,
                      ),
                      _FeedSection(
                        title: 'Bạn bè vừa ghé',
                        places: _feed.friendsActivity,
                        onTap: _openPlace,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF1F1F1),
            foregroundColor: const Color(0xFF171717),
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Hôm nay ăn gì cho vibe?',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF171717),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onAiTap;

  const _SearchBar({
    required this.controller,
    required this.isLoading,
    required this.onSubmitted,
    required this.onAiTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.only(left: 8, right: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: onAiTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                    backgroundColor: const Color(0xFFEF4050),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Hỏi AI',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: Color(0xFF171717)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Tìm nhà hàng, quán ăn...',
                      hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: () => onSubmitted(controller.text),
                    icon: const Icon(Icons.search_rounded, size: 21),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: () {},
          style: IconButton.styleFrom(
            fixedSize: const Size(48, 48),
            backgroundColor: const Color(0xFFF1F1F1),
            foregroundColor: const Color(0xFFEF4050),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

class _AddPlaceBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPlaceBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0E3), Color(0xFFF2F0EC)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHƯA TÌM ĐƯỢC QUÁN YÊU THÍCH?',
            style: TextStyle(
              color: Color(0xFFD92F40),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hãy thêm địa điểm mới và chia sẻ với mọi người!',
            style: TextStyle(color: Color(0xFFB25F67), fontSize: 12),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4050),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Thêm ngay vào bản đồ!',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE90016), Color(0xFFFF4553)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phường Bến Thành, TP.HCM',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text('Thay đổi', style: TextStyle(color: Colors.white70)),
                SizedBox(height: 8),
                Text(
                  '24°C',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(Icons.umbrella_rounded, color: Colors.white, size: 38),
              SizedBox(height: 8),
              Text('Mưa phùn', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

class _VibeGrid extends StatelessWidget {
  const _VibeGrid();

  static const vibes = [
    (Icons.favorite_rounded, 'Hẹn hò'),
    (Icons.groups_rounded, 'Nhóm bạn'),
    (Icons.menu_book_rounded, 'Học/Làm việc'),
    (Icons.dark_mode_rounded, 'Chill'),
    (Icons.auto_awesome_rounded, 'Lãng mạn'),
    (Icons.eco_rounded, 'Không gian xanh'),
    (Icons.music_note_rounded, 'Acoustic'),
    (Icons.local_cafe_rounded, 'Cafe'),
    (Icons.cake_rounded, 'Ngọt ngào'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vibes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (_, index) {
        final vibe = vibes[index];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF3F4), Color(0xFFFFDADD)],
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(vibe.$1, color: const Color(0xFFEF4050), size: 24),
              const SizedBox(height: 7),
              Text(
                vibe.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF272727),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedSection extends StatelessWidget {
  final String title;
  final List<DiscoveryPlace> places;
  final ValueChanged<DiscoveryPlace> onTap;

  const _FeedSection({
    required this.title,
    required this.places,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title),
          const SizedBox(height: 14),
          _PlaceList(places: places, onTap: onTap),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF171717),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(color: Color(0xFF777777))),
      ],
    );
  }
}

class _PlaceList extends StatelessWidget {
  final List<DiscoveryPlace> places;
  final ValueChanged<DiscoveryPlace> onTap;
  final String emptyMessage;

  const _PlaceList({
    required this.places,
    required this.onTap,
    this.emptyMessage = 'Chưa có địa điểm nổi bật hôm nay.',
  });

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return _MessageCard(message: emptyMessage);
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: places.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => _PlaceCard(
          place: places[index],
          onTap: () => onTap(places[index]),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final DiscoveryPlace place;
  final VoidCallback onTap;

  const _PlaceCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = place.coverMediaId;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 190,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 104,
              width: double.infinity,
              child: imageUrl != null && imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _PlaceImageFallback(),
                    )
                  : const _PlaceImageFallback(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF171717),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${place.categoryLabel} • ${place.distanceMeters}m',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 17),
                        const SizedBox(width: 3),
                        Text(
                          place.avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFF171717),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${place.checkinCount} check-in',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFEF4050),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceImageFallback extends StatelessWidget {
  const _PlaceImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFE4E6),
      child: const Icon(Icons.restaurant_rounded, color: Color(0xFFEF4050), size: 40),
    );
  }
}

class _PlaceSkeleton extends StatelessWidget {
  const _PlaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 224,
      width: 190,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF777777))),
    );
  }
}
