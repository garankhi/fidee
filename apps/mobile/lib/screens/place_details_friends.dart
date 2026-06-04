import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/place_provider.dart'; // Đảm bảo đúng path dẫn tới file bạn vừa gửi

class PlaceDetailsFriends extends ConsumerStatefulWidget {
  const PlaceDetailsFriends({super.key});

  @override
  ConsumerState<PlaceDetailsFriends> createState() => _PlaceDetailsFriendsState();
}

class _PlaceDetailsFriendsState extends ConsumerState<PlaceDetailsFriends> {
  @override
  Widget build(BuildContext context) {
    // Đọc trạng thái đồng bộ hiện tại từ PlaceController của bạn
    final place = ref.watch(placeControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: const Color(0x19EF484F),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFFEF484F)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          (place.name ?? 'CHI TIẾT ĐỊA ĐIỂM').toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFEF484F),
            fontSize: 20,
            fontFamily: 'Erica One',
            fontWeight: FontWeight.w400,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: const Color(0x19EF484F),
              child: IconButton(
                icon: const Icon(Icons.share, size: 18, color: Color(0xFFEF484F)),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Banner Image & Info Card
                _buildBannerCard(place),
                const SizedBox(height: 20),

                // 2. Thông tin quán
                _buildInfoQuan(place),
                const SizedBox(height: 20),

                // 3. Category Tags phân loại
                _buildCategoryTags(place),
                const SizedBox(height: 20),

                // 4. Tiện nghi đi kèm
                _buildAmenities(),
                const SizedBox(height: 25),

                // 5. Nút chỉ đường tích hợp tọa độ lat, lng từ state
                _buildLargeButton(
                  Icons.near_me,
                  'Chỉ đường ${(place.lat != null && place.lng != null) ? '(${place.lat!.toStringAsFixed(4)}, ${place.lng!.toStringAsFixed(4)})' : ''}',
                ),
                const SizedBox(height: 25),

                // 6. Khu vực Check-in của bạn bè
                _buildFriendCheckins(),
                const SizedBox(height: 25),

                // 7. Khu vực đánh giá
                _buildFriendReviews(),
                const SizedBox(height: 25),

                // 8. Thư viện Ảnh
                _buildPhotoGallery(),
              ],
            ),
          ),

          // Bottom Action Bar cố định nổi mượt mà phía dưới cùng
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Row(
              children: [
                Expanded(
                  child: _buildBottomButton(Icons.camera_alt, 'Check-in'),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildBottomButton(Icons.edit, 'Đánh giá'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENT WIDGETS ---

  Widget _buildBannerCard(Place place) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: NetworkImage("https://placehold.co/400x240"), // Thay link ảnh thật của quán nếu lưu trong State
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
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
                children: const [
                  Icon(Icons.star, color: Colors.amber, size: 16),
                  SizedBox(width: 4),
                  Text('4.9', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              radius: 18,
              child: const Icon(Icons.favorite_border, color: Colors.white, size: 18),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
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
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📍 ${place.address ?? "Chưa cập nhật địa chỉ"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF229D00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Đang mở cửa',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đóng ${place.closeTime ?? "22:00"}',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoQuan(Place place) {
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THÔNG TIN QUÁN',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Mô tả:', ' Là thương hiệu mì Udon số 1 Nhật Bản'),
          _buildInfoRow('Khung giờ hoạt động:', ' ${place.openTime ?? "11:00"} - ${place.closeTime ?? "22:00"}'),
          _buildInfoRow('Tầm giá:', ' 50k - 100k VND'),
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
            TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
            TextSpan(text: value, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTags(Place place) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTag(place.category != null ? '🍜 ${place.category}' : '🍜 Món Nhật'),
        _buildTag('💵 Tầm Giá Tốt'),
        _buildTag('🕯️ Ấm cúng'),
        _buildTag('👪 Gia đình'),
      ],
    );
  }

  Widget _buildAmenities() {
    final List<String> amenities = ['Wifi', 'Trong nhà', 'Chỗ đỗ ô tô'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tiện nghi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amenities.map((amenity) => _buildTag(amenity)).toList(),
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
        boxShadow: [
          BoxShadow(color: const Color(0xFFF7C6C7).withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF46090C), fontWeight: FontWeight.w600, fontSize: 13),
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
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFriendCheckins() {
    final List<Map<String, String>> mockCheckins = [
      {'name': 'Khanh', 'time': 'hôm nay', 'rot': '-0.03'},
      {'name': 'Minh', 'time': 'tuần trước', 'rot': '0.04'},
      {'name': 'Thông', 'time': '23.03.26', 'rot': '-0.01'},
    ];

    return Column(
      children: [
        _buildSectionHeader('Check-in của bạn bè'),
        const SizedBox(height: 12),
        SizedBox(
          height: 165,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: mockCheckins.length,
            itemBuilder: (context, index) {
              final item = mockCheckins[index];
              return Transform.rotate(
                angle: double.parse(item['rot']!),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 12, bottom: 5, top: 5),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFC5C5C5).withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFF7C6C7).withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network("https://placehold.co/130x110", fit: BoxFit.cover, width: double.infinity),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(item['time']!, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendReviews() {
    return Column(
      children: [
        _buildSectionHeader('Bạn bè nói gì về quán này?'),
        const SizedBox(height: 12),
        _buildReviewCard('Minh', 'đi nhóm 4 ngon, hơi đông giờ tối — đi sớm nhé bro', 'NỔI BẬT', const Color(0xFFEF484F)),
        const SizedBox(height: 12),
        _buildReviewCard('Ha', 'Thích nhất món Udon bò, bò mềm, nước dùng ngọt. Chắc chắn sẽ quay lại!', 'ĐƯỢC GỢI Ý', const Color(0xFFEF484F)),
      ],
    );
  }

  Widget _buildReviewCard(String name, String comment, String tag, Color tagColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF7C6C7), Color(0x91EAE9E8)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage("https://placehold.co/40x40"),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name · 5n', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Row(
                    children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.amber, size: 12)),
                  )
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(12)),
                child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(comment, style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery() {
    return Column(
      children: [
        _buildSectionHeader('Ảnh'),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(color: const Color(0xFFE6E6E6), borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 32),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 2,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: const DecorationImage(
                          image: NetworkImage("https://placehold.co/150x150"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () {},
          child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFFEF484F), fontSize: 13, fontWeight: FontWeight.bold)),
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}