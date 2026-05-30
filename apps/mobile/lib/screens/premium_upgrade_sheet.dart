import 'package:flutter/material.dart';

class PremiumUpgradeSheet extends StatelessWidget {
  const PremiumUpgradeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFF252020),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 80, left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo/Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage("assets/images/Fidee_Red_Round.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tiêu đề
                  const Text(
                    'FIDEE Pro',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFEF484F), fontSize: 50, fontFamily: 'SF Pro', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Subtitle
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'SF Pro', height: 1.5, fontWeight: FontWeight.w500),
                      children: [
                        TextSpan(text: 'Nâng cao trải nghiệm với gói '),
                        TextSpan(text: 'Pro\n', style: TextStyle(color: Color(0xFFEF484F), fontWeight: FontWeight.bold, fontSize: 22)),
                        TextSpan(text: 'khi sử dụng '),
                        TextSpan(text: 'FIDEE', style: TextStyle(color: Color(0xFFEF484F), fontWeight: FontWeight.bold, fontSize: 22)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Danh sách tính năng
                  _buildFeatureItem('🚫', 'Tắt quảng cáo', 'Không hiện quảng cáo trong ứng dụng!'),
                  _buildFeatureItem('🎥', 'FIDEE Videos', 'Quay video check-in ngắn'),
                  _buildFeatureItem('🖼️', 'Đăng ảnh từ thư viện', 'Chia sẻ khoảnh khắc từ thư viện của bạn'),
                  _buildFeatureItem('🗺️', 'Bản đồ nhóm', 'Tạo bản đồ riêng cho nhóm bạn bè'),
                  _buildFeatureItem('🤖', 'Thêm số lượt hỏi AI', '20 lượt hỏi AI mỗi ngày!'),
                  _buildFeatureItem('👥', 'Kết nối nhiều bạn hơn', 'Không giới hạn số lượng bạn bè'),
                  _buildFeatureItem('💬', 'Viết mô tả dài hơn', 'Câu mô tả dài hơn cho ảnh check-in!'),
                  _buildFeatureItem('✨', 'Tùy chỉnh biểu tượng ứng dụng', 'Trang trí Màn hình chính của bạn'),
                ],
              ),
            ),
          ),

          // Phần Nút bấm cố định ở dưới cùng
          Container(
            padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 30),
            decoration: const BoxDecoration(
              color: Color(0xFF252020),
              boxShadow: [
                BoxShadow(color: Color(0xFF252020), blurRadius: 20, offset: Offset(0, -10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nút "Nâng cấp ngay!"
                GestureDetector(
                  onTap: () {
                    //
                  },
                  child: Container(
                    width: double.infinity,
                    height: 55,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF484F),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Text(
                      'Nâng cấp ngay!',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'SF Pro', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Nút "Không, cảm ơn!"
                GestureDetector(
                  onTap: () => Navigator.pop(context), // Đóng modal
                  child: Container(
                    width: double.infinity,
                    height: 55,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x66FFD2D2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Text(
                      'Không, cảm ơn!',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'SF Pro', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget hỗ trợ để tái sử dụng mã cho từng hàng tính năng
  Widget _buildFeatureItem(String emoji, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0x66FFD2D2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'SF Pro', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14, fontFamily: 'SF Pro', fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}