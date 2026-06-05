import 'package:fidee_mobile/screens/add_spot_screen.dart';
import 'package:fidee_mobile/screens/ai_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import '../models/nearby_place.dart';
import '../services/nearby_service.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  List<NearbyPlace> _nearbySpots = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNearbySpots();
  }

  Future<void> _loadNearbySpots() async {
    try {
      final authService = ref.read(authServiceProvider);
      final nearbyService = NearbyService(authService);
      // Note: We don't have real location here, using default for demo
      final res = await nearbyService.fetchNearby(
        lat: 10.762892,
        lng: 106.682586,
        mediaId: 'explore_${DateTime.now().millisecondsSinceEpoch}',
      );
      setState(() {
        _nearbySpots = res.data.where((p) => !p.isCustomFallback).toList();
      });
    } catch (e) {
      // Do nothing
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

  void _onFilterTap() {
    // TODO: Implement filter functionality
    print('Filter tapped');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === Header: Back Button & Title ===
                const SizedBox(height: 12),
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
                    const SizedBox(width: 12),
                    const Text(
                      'Hôm nay ăn gì cho vibe?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // === Search Bar ===
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFFEF4050)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Tìm kiếm, quán ăn...',
                          hintStyle: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _onFilterTap,
                      child: Icon(Icons.filter_list, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
                const SizedBox(height: 24),

                // === "Chưa tìm được quán?" Banner ===
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFEF4050).withValues(alpha: 0.1),
                        const Color(0xFFEF4050).withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHƯA TÌM ĐƯỢC\nQUÁN YÊU THÍCH?',
                        style: TextStyle(
                          color: Color(0xFFEF4050),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hãy thêm địa điểm mới và chia sẻ với mọi người!',
                        style: TextStyle(
                          color: Color(0xFF8D8D8D),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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
                ),
                const SizedBox(height: 28),

                // === "Vibe hôm nay là gì?" Text ===
                const Text(
                  '"Vibe" hôm nay là gì?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),

                // === Weather Card ===
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thứ 2',
                            style: TextStyle(
                              color: Color(0xFF8D8D8D),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'TP. Hồ Chí Minh',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '24°C',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4050).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud,
                          color: Color(0xFFEF4050),
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // === Category Chips ===
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _CategoryChip(label: 'Hẹn hò'),
                    _CategoryChip(label: 'Nhậu'),
                    _CategoryChip(label: 'Họp làm'),
                    _CategoryChip(label: 'Chill'),
                    _CategoryChip(label: 'Lãng mạng'),
                    _CategoryChip(label: 'Không gian'),
                    _CategoryChip(label: 'Acoustic'),
                    _CategoryChip(label: 'Cafe'),
                    _CategoryChip(label: 'Ngọt ngào'),
                  ],
                ),
                const SizedBox(height: 32),

                // === Đang "hot" Section ===
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đang "hot"',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Xem tất cả',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFEF4050),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 230,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      _PlaceCard(
                        imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400',
                        name: 'B2Q Saigon',
                        tags: ['Đang mở', 'Cafe', 'Nhạc chill', 'Quán quen'],
                      ),
                      SizedBox(width: 14),
                      _PlaceCard(
                        imageUrl: 'https://images.unsplash.com/photo-1521017431713-00b87e4c16b3?w=400',
                        name: 'Kyoto Zen',
                        tags: ['Đang mở', 'Nhật Bản', 'Yêu thích', 'Ngọt ngào'],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // === Dựa trên quán bạn đã chọn Section ===
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dựa trên quán bạn đã chọn',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Xem tất cả',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFEF4050),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 230,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      _PlaceCard(
                        imageUrl: 'https://images.unsplash.com/photo-1554679665-f5537f187268?w=400',
                        name: 'Moonlight Ramen',
                        tags: ['Đang mở', 'Nhật Bản', 'Hẹn hò', 'Cơm gạo'],
                      ),
                      SizedBox(width: 14),
                      _PlaceCard(
                        imageUrl: 'https://images.unsplash.com/photo-1551288049-bebda4e38e71?w=400',
                        name: 'The Garden',
                        tags: ['Đang mở', 'Thoải mái', 'Ăn vặt', 'Nhóm bạn'],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // === Dựa trên hoạt động của bạn bè Section ===
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dựa trên hoạt động của bạn bè',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Xem tất cả',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFEF4050),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 230,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      _PlaceCard(
                        imageUrl: 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?w=400',
                        name: 'Moonlight Ramen',
                        tags: ['Đang mở', 'Nhật Bản', 'Hẹn hò', 'Cơm gạo'],
                        friendAvatars: ['AA', 'BB', 'CC'],
                      ),
                      SizedBox(width: 14),
                      _PlaceCard(
                        imageUrl: 'https://images.unsplash.com/photo-1567016432779-094069958ea5?w=400',
                        name: 'Moonlight Ramen',
                        tags: ['Đang mở', 'Nhật Bản', 'Hẹn hò', 'Cơm gạo'],
                        friendAvatars: ['DD', 'EE'],
                      ),
                      SizedBox(width: 14),
                      _PlaceCard(
                        imageUrl: 'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?w=400',
                        name: 'Moonlight Ramen',
                        tags: ['Đang mở', 'Nhật Bản', 'Hẹn hò', 'Cơm gạo'],
                        friendAvatars: ['FF'],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // === Hỏi AI Button ===
                Center(
                  child: GestureDetector(
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
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4050),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4050).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Hỏi AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;

  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final List<String> tags;
  final List<String>? friendAvatars;

  const _PlaceCard({
    required this.imageUrl,
    required this.name,
    required this.tags,
    this.friendAvatars,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Place Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 130,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          // Place Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          // Tags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          // Friend Avatars
          if (friendAvatars != null && friendAvatars!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  ...friendAvatars!.asMap().entries.map(
                        (entry) => Transform.translate(
                          offset: Offset(-entry.key * 12.0, 0),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5A8DEE),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
