import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/place_provider.dart';
import '../features/auth/review_provider.dart';
import 'camera_screen.dart';

class PlaceDetailsFriends extends ConsumerStatefulWidget {
  final String placeId;

  const PlaceDetailsFriends({super.key, required this.placeId});

  @override
  ConsumerState<PlaceDetailsFriends> createState() =>
      _PlaceDetailsFriendsState();
}

class _PlaceDetailsFriendsState extends ConsumerState<PlaceDetailsFriends> {
  static const String _serverBaseUrl = 'https://api.fidee.site';

  String _getFullImageUrl(dynamic mediaId) {
    if (mediaId == null || mediaId.toString().isEmpty) {
      return 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=500';
    }

    final value = mediaId.toString();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    return '$_serverBaseUrl/media/$value';
  }

  String _formatDisplayTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'Chưa rõ';
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return timeStr;
  }

  void _showSuccessDialog(int rating, String content) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text(
                'Thành công!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Đóng',
                style: TextStyle(color: Color(0xFFEF484F), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref
          .read(placeControllerProvider.notifier)
          .fetchPlaceDetail(widget.placeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final place = ref.watch(placeControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  toolbarHeight: 100,
                  pinned: true,
                  backgroundColor: Colors.white,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 10),
                    child: Center(
                      child: CircleAvatar(
                        backgroundColor: const Color(0x19EF484F),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: Color(0xFFEF484F),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                  title: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      (place.name ?? 'CHI TIẾT ĐỊA ĐIỂM').toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFC52128),
                        fontSize: 22,
                        fontFamily: 'Anton',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 10,
                      ),
                      child: Center(
                        child: CircleAvatar(
                          backgroundColor: const Color(0x19EF484F),
                          child: IconButton(
                            icon: const Icon(
                              Icons.share,
                              size: 18,
                              color: Color(0xFFEF484F),
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 10,
                    bottom: 120,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildBannerCard(place),
                      const SizedBox(height: 20),
                      _buildInfoSpot(place),
                      const SizedBox(height: 20),
                      _buildCategoryTags(place),
                      const SizedBox(height: 20),
                      _buildAmenities(place),
                      const SizedBox(height: 25),
                      _buildLargeButton(Icons.near_me, 'Chỉ đường'),
                      const SizedBox(height: 25),
                      _buildFriendCheckins(place),
                      const SizedBox(height: 25),
                      _buildFriendReviews(place),
                      const SizedBox(height: 25),
                      _buildPhotoGallery(place),
                    ]),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const CameraScreen(),
                              ),
                            );
                          },
                          child: _buildBottomButton(Icons.camera_alt, 'Check-in'),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showRatingBottomSheet(),
                          child: _buildBottomButton(Icons.edit, 'Đánh giá'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPONENT WIDGETS ---

  Widget _buildBannerCard(Place place) {
    final bannerUrl = _getFullImageUrl(place.coverMediaId);

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF303E42),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (bannerUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, __) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.white30,
                      ),
                    );
                  },
                ),
              ),

            if (bannerUrl.isEmpty)
              const Center(
                child: Icon(Icons.image, size: 40, color: Colors.white30),
              ),

            Positioned(
              top: 15,
              left: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      place.avgRating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            place.name ?? 'Chưa cập nhật tên',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '📍 ${place.address ?? "Chưa cập nhật địa chỉ"}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF229D00),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Đang mở cửa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đóng ${_formatDisplayTime(place.closeTime)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10,
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

  Widget _buildInfoSpot(Place place) {
    String formatCurrency(int? amount) {
      if (amount == null) return '0';
      if (amount >= 1000) return '${amount ~/ 1000}k';
      return amount.toString();
    }

    final String priceRange = (place.priceMin != null && place.priceMax != null)
        ? '${formatCurrency(place.priceMin)} - ${formatCurrency(place.priceMax)} VND'
        : 'Chưa cập nhật tầm giá';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7C6C7), Color(0xFFF2F1F0)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THÔNG TIN QUÁN',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Mô tả:',
            ' ${place.description ?? "Chưa có mô tả chi tiết cho địa điểm này."}',
          ),
          _buildInfoRow(
            'Khung giờ hoạt động:',
            ' ${_formatDisplayTime(place.openTime)} - ${_formatDisplayTime(place.closeTime)}',
          ),
          _buildInfoRow('Tầm giá:', ' $priceRange'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTags(Place place) {
    if (place.vibes.isNotEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: place.vibes
            .map((vibe) => _buildTag('✨ ${vibe.toUpperCase()}'))
            .toList(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTag(
          place.category != null
              ? '✨ ${place.category!.toUpperCase()}'
              : '✨ CAFE',
        ),
        _buildTag('🛡️ Đã xác minh'),
        _buildTag('💵 Tầm Giá Tốt'),
      ],
    );
  }

  Widget _buildAmenities(Place place) {
    if (place.services.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tiện nghi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: place.services
              .map((service) => _buildTag(service.toString()))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF46090C),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildLargeButton(IconData icon, String text) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFEF484F),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCheckins(Place place) {
    final checkins = place.friendCheckins;

    return Column(
      children: [
        _buildSectionHeader('Check-in của bạn bè (${place.checkinCount})'),
        const SizedBox(height: 12),
        SizedBox(
          height: 165,
          child: checkins.isEmpty
              ? const Center(child: Text('Chưa có check-in nào', style: TextStyle(color: Colors.grey, fontSize: 13)))
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: checkins.length,
            itemBuilder: (context, index) {
              final item = checkins[index] as Map<String, dynamic>;

              final String checkinPhoto = _getFullImageUrl(
                item['mediaId'] ?? item['url'],
              );

              return Container(
                width: 130,
                margin: const EdgeInsets.only(right: 12, bottom: 5, top: 5),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFC5C5C5).withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['userName']?.toString() ?? item['name']?.toString() ?? 'Bạn bè',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: checkinPhoto.isNotEmpty
                            ? Image.network(
                          checkinPhoto,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, color: Colors.white),
                          ),
                        )
                            : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        item['createdAt']?.toString().split('T').first ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendReviews(Place place) {
    final reviews = place.friendReviews;

    if (reviews.isEmpty) {
      return Column(
        children: [
          _buildSectionHeader('Bạn bè nói gì về quán này?'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Chưa có đánh giá từ bạn bè',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSectionHeader('Bạn bè nói gì về quán này? (${reviews.length})'),
        const SizedBox(height: 12),
        ...reviews.map((review) {
          final item = review as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildReviewCard(item),
          );
        }),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final bool isFeatured = review['isFeatured'] == true;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7C6C7), Color(0x91EAE9E8)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['userName']?.toString() ?? 'Người dùng',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        (review['rating'] ?? 0) as int,
                            (index) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFeatured ? const Color(0xFFEF484F) : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFeatured ? 'NỔI BẬT' : 'ĐÁNH GIÁ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review['content']?.toString() ?? '',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery(Place place) {
    final photos = place.photos;

    return Column(
      children: [
        _buildSectionHeader('Ảnh (${photos.length})'),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE6E6E6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: Colors.grey,
                size: 32,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 100,
                child: photos.isEmpty
                    ? const Center(child: Text('Chưa có ảnh', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photoItem = photos[index] as Map<String, dynamic>;
                    final String galleryPhotoUrl = _getFullImageUrl(
                      photoItem['mediaId'] ?? photoItem['url'],
                    );
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: const Color(0xFF303E42),
                        image: galleryPhotoUrl.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(galleryPhotoUrl),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          if (galleryPhotoUrl.isEmpty)
                            const Center(child: Icon(Icons.image, color: Colors.white24)),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(15),
                                  bottomRight: Radius.circular(15),
                                ),
                              ),
                              child: Text(
                                photoItem['userName']?.toString() ?? 'Ẩn danh',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Xem tất cả',
            style: TextStyle(
              color: Color(0xFFEF484F),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(IconData icon, String text) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFEF484F),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return NewRatingBottomSheet(
          placeId: widget.placeId,
          onSuccess: (rating, content) {
            ref
                .read(placeControllerProvider.notifier)
                .fetchPlaceDetail(widget.placeId);

            if (context.mounted) {
              _showSuccessDialog(rating, content);
            }
          },
        );
      },
    );
  }
}

class NewRatingBottomSheet extends ConsumerStatefulWidget {
  final String placeId;
  final Function(int rating, String content) onSuccess;

  const NewRatingBottomSheet({
    super.key,
    required this.placeId,
    required this.onSuccess,
  });

  @override
  ConsumerState<NewRatingBottomSheet> createState() => _NewRatingBottomSheetState();
}

class _NewRatingBottomSheetState extends ConsumerState<NewRatingBottomSheet> {
  int _rating = 0;
  bool _isPrivate = false;
  final TextEditingController _commentController = TextEditingController();

  final List<String> _tags = ['Vibe chill', 'Phục vụ nhanh', 'Hợp khẩu vị'];
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewControllerProvider);
    final bool isLoading = reviewState.isLoading;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- HEADER BAR ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                ),
                const Text(
                  'GỬI ĐÁNH GIÁ',
                  style: TextStyle(
                    color: Color(0xFFB92830),
                    fontSize: 28,
                    fontFamily: 'Anton',
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.36,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 22),

            // --- UPLOAD ẢNH CHECK-IN (Giữ UI, chưa đính kèm payload API) ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Thả ảnh check-in của bạn ',
                      style: TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 16,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E6E6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: Color(0xFFA6A6A6),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // --- CHỌN SỐ SAO (RATING) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: isLoading ? null : () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                  icon: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: index < _rating ? Colors.amber : const Color(0xFFD9D9D9),
                    size: 40,
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),

            // --- DANH SÁCH TAGS ---
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _tags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return InkWell(
                  onTap: isLoading ? null : () {
                    setState(() {
                      if (isSelected) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEF484F) : const Color(0x19FF9296),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSelected ? '✓ ' : '+ ',
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFEF484F),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          tag,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFEF484F),
                            fontSize: 14,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // --- Ô NHẬP CẢM NHẬN ---
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 500,
              enabled: !isLoading,

              style: const TextStyle(
                color: Color(0xFF1E1E1E),
                fontSize: 16,
                fontFamily: 'SF Pro',
              ),

              decoration: InputDecoration(
                hintText: 'Chia sẻ cảm nhận của bạn...',
                hintStyle: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 15),
                fillColor: const Color(0x7FEFEFEF),
                filled: true,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFEF484F)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- ẨN DANH / RIÊNG TƯ SWITCH ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hiển thị đánh giá ẩn danh',
                  style: TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontSize: 16,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Switch.adaptive(
                  value: _isPrivate,
                  activeColor: const Color(0xFFEF484F),
                  onChanged: isLoading ? null : (value) {
                    setState(() {
                      _isPrivate = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),

            // --- NÚT XÁC NHẬN ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_rating == 0 || isLoading)
                    ? null
                    : () async {
                  String finalContent = _commentController.text.trim();
                  if (_selectedTags.isNotEmpty) {
                    final String tagsString = _selectedTags.map((e) => '#$e').join(' ');
                    finalContent = finalContent.isEmpty
                        ? tagsString
                        : '$finalContent\n$tagsString';
                  }

                  final String visibilityParam = _isPrivate ? 'PRIVATE' : 'FRIENDS';

                  final Map<String, dynamic> apiPayload = {
                    'placeId': widget.placeId,
                    'candidateId': null,
                    'rating': _rating,
                    'content': finalContent.isEmpty ? null : finalContent,
                    'visibility': visibilityParam,
                  };

                  final isSuccess = await ref
                      .read(reviewControllerProvider.notifier)
                      .submitReview(apiPayload);

                  if (isSuccess && context.mounted) {
                    Navigator.pop(context);
                    widget.onSuccess(_rating, finalContent);

                    ref.read(reviewControllerProvider.notifier).resetState();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF484F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  'Xác nhận',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}