import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/auth/candidate_provider.dart';
import 'place_details_friends.dart';

class CandidateFeedScreen extends ConsumerStatefulWidget {
  const CandidateFeedScreen({super.key});

  @override
  ConsumerState<CandidateFeedScreen> createState() =>
      _CandidateFeedScreenState();
}

class _CandidateFeedScreenState extends ConsumerState<CandidateFeedScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref
          .read(candidateControllerProvider.notifier)
          .loadCandidates(lat: 10.762622, lng: 106.660172, radiusKm: 20);
    });
  }

  String _formatCreatedAt(String? createdAtString) {
    if (createdAtString == null || createdAtString.isEmpty) {
      return 'Không rõ thời gian';
    }

    try {
      final createdAt = DateTime.parse(createdAtString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(createdAt);

      if (difference.inSeconds < 60) {
        return 'Vừa xong';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} phút trước';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} ngày trước';
      } else {
        return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
      }
    } catch (e) {
      return 'Thời gian không hợp lệ';
    }
  }

  String _formatHours(String? open, String? close) {
    if (open == null || close == null) return 'Chưa cập nhật giờ';
    final openFormatted = open.length > 5 ? open.substring(0, 5) : open;
    final closeFormatted = close.length > 5 ? close.substring(0, 5) : close;
    return '$openFormatted - $closeFormatted';
  }

  String _formatPrice(dynamic min, dynamic max) {
    if (min == null && max == null) return 'Chưa cập nhật giá';
    if (min != null && max == null) return 'Từ ${min}đ';
    if (min == null && max != null) return 'Đến ${max}đ';
    return '${min}đ - ${max}đ';
  }

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(candidateControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'BẢNG TIN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF484F),
            fontFamily: 'Anton',
            fontSize: 30,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: candidatesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),

        error: (err, _) => Center(child: Text('Đã xảy ra lỗi: $err')),

        data: (candidates) {
          if (candidates.isEmpty) {
            return const Center(
              child: Text('Không có địa điểm nào trong bán kính 20km'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(candidateControllerProvider.notifier)
                  .refresh(lat: 10.762622, lng: 106.660172, radiusKm: 20);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final candidate = candidates[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PlaceDetailsFriends(placeId: candidate.id),
                      ),
                    );
                  },
                  child: _buildCandidateCard(candidate),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCandidateCard(CandidatePlace place) {
    final String? avatarUrl = place.createdByAvatar;
    final String? mediaId = place.mediaId;

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  place.name ?? 'Chưa có tên',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          place.createdByName ?? place.createdByUsername ?? 'Người dùng',
                          style: const TextStyle(
                            color: Color(0xFF0E1B16),
                            fontSize: 16,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.32,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCreatedAt(place.createdAt),
                          style: const TextStyle(
                            color: Color(0xFFEF484F),
                            fontSize: 11,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            place.address ?? 'Chưa có địa chỉ',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),

          const SizedBox(height: 12),

          if (place.category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                place.category!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 15),

          if (place.description != null && place.description!.isNotEmpty) ...[
            const SizedBox(height: 12),

            Text(
              place.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 15),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  place.createdByName ??
                      place.createdByUsername ??
                      'Người dùng',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.red[400], size: 22),
                      const SizedBox(width: 6),
                      const Text(
                        '',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.grey[700], size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        '',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.send_outlined, color: Colors.grey[700], size: 20),
                    onPressed: () {},
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.bookmark_border_rounded, color: Colors.grey[700], size: 22),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 32),
          SizedBox(height: 4),
          Text(
            'Không có ảnh',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          )
        ],
      ),
    );
  }
}
