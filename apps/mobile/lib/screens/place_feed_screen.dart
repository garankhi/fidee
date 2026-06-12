import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'place_details_friends.dart'; // Import màn hình chi tiết cũ của bạn
import '../features/auth/place_provider.dart';

class PlaceFeedScreen extends ConsumerWidget {
  const PlaceFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lắng nghe danh sách địa điểm từ feed provider mới
    final feedAsync = ref.watch(placeFeedControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('MapVibe Feed', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF484F))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, _) => Center(child: Text('Đã xảy ra lỗi: $err')),
        data: (places) {
          if (places.isEmpty) {
            return const Center(child: Text('Chưa có địa điểm nào quanh đây.'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(placeFeedControllerProvider.notifier).refreshFeed(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return GestureDetector(
                  onTap: () {
                    // Chuyển hướng sang màn hình của bạn mà KHÔNG LÀM THAY ĐỔI CONSTRUCTOR
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PlaceDetailsFriends(placeId: place.id ?? ''),
                      ),
                    );
                  },
                  child: _buildFeedCard(place),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Card UI hiển thị tóm tắt ngoài bảng tin Feed
  Widget _buildFeedCard(Place place) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tên quán & Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  place.name ?? 'Chưa cập nhật tên',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    place.avgRating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 6),
          // Địa chỉ
          Text(
            '📍 ${place.address ?? "Chưa cập nhật địa chỉ"}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          // Mấy tag Vibes của quán (nếu có)
          if (place.vibes.isNotEmpty)
            Wrap(
              spacing: 6,
              children: place.vibes.take(3).map((vibe) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFCEDEE), borderRadius: BorderRadius.circular(12)),
                child: Text('#$vibe', style: const TextStyle(color: Color(0xFFEF484F), fontSize: 11, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
        ],
      ),
    );
  }
}