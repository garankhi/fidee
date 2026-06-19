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
  final String _selectedStatus = 'PENDING_REVIEW';

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref
          .read(candidateControllerProvider.notifier)
          .loadCandidates(status: _selectedStatus);
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
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        error: (err, _) => Center(
          child: Text('Đã xảy ra lỗi: $err'),
        ),
        data: (candidates) {
          if (candidates.isEmpty) {
            return const Center(
              child: Text(
                'Không có địa điểm nào cần duyệt',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(candidateControllerProvider.notifier)
                  .refresh(status: _selectedStatus);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final candidate = candidates[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PlaceDetailsFriends(
                          placeId: candidate.id,
                        ),
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

    return Card(
      elevation: 4,
      shadowColor: const Color(0x1436634E),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        borderRadius: BorderRadius.circular(30),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : const NetworkImage('https://ui-avatars.com/api/?name=User'),
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
            ),
            const SizedBox(height: 15),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name ?? 'Chưa có tên',
                    style: const TextStyle(
                      color: Color(0xFF0E1B16),
                      fontSize: 20,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📍 Địa chỉ: ${place.address ?? "Chưa cập nhật địa chỉ"}\n'
                        '📞 SĐT: ${place.phoneNumber ?? "Chưa cập nhật SĐT"}\n'
                        '💵 Giá: ${_formatPrice(place.priceMin, place.priceMax)}\n'
                        '🕗 Giờ mở cửa: ${_formatHours(place.openTime, place.closeTime)}',
                    style: const TextStyle(
                      color: Color(0xFF0E1B16),
                      fontSize: 13,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            SizedBox(
              height: 200,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: mediaId != null && !mediaId.contains('mock')
                        ? Image.network(
                      mediaId,
                      width: 160,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                    )
                        : _buildImagePlaceholder(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            if (place.description != null && place.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  place.description!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0E1B16),
                    fontSize: 13,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                    height: 1.54,
                    letterSpacing: -0.26,
                  ),
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