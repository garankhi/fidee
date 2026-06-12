import 'package:flutter/material.dart';
import 'package:fidee_mobile/screens/profile_screen.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final String? userAvatarUrl;
  final ValueChanged<int> onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.userAvatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 15, right: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 350,
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8), // Thêm chút padding ngang cho thoáng
              decoration: ShapeDecoration(
                color: const Color(0xA8E78B8B),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    width: 0.80,
                    strokeAlign: BorderSide.strokeAlignOutside,
                    color: Color(0xFFEF484F),
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Icon Layers (Index 0)
                  _buildNavItem(Icons.layers, currentIndex == 0, () => onTap(0)),

                  // 2. Icon Compass - Nút chính nổi bật ở giữa (Index 1)
                  _buildNavItem(Icons.explore, currentIndex == 1, () => onTap(1), isCenterActive: true),

                  // 3. Icon Inbox / Notifications (Index 2)
                  _buildNavItem(Icons.move_to_inbox, currentIndex == 2, () => onTap(2)),

                  // 4. Avatar User (Index 3)
                  GestureDetector(
                    onTap: () => onTap(3), // CHỈ CẦN GỌI ONTAP(3), để màn hình cha tự chuyển tab sang ProfileScreen
                    child: Container(
                      width: 65,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFD4DA),
                            border: Border.all(
                                color: currentIndex == 3 ? const Color(0xFFEF484F) : Colors.white,
                                width: 1.5
                            ),
                            image: userAvatarUrl != null && userAvatarUrl!.isNotEmpty
                                ? DecorationImage(
                              image: NetworkImage(userAvatarUrl!),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: userAvatarUrl == null || userAvatarUrl!.isEmpty
                              ? const Center(
                            child: Icon(Icons.person, size: 18, color: Color(0xFFEF484F)),
                          )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, bool isActive, VoidCallback onTap, {bool isCenterActive = false}) {
    // Nếu là nút giữa và đang active, dùng màu nền đỏ đậm bự hơn giống thiết kế chính thức
    final bool showRedBackground = isActive && isCenterActive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: showRedBackground ? 85 : 65, // Nút giữa khi active sẽ to bè ra chiếm không gian như trong ảnh
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: ShapeDecoration(
          color: showRedBackground ? const Color(0xFFEF484F) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(33),
          ),
        ),
        child: Icon(
          icon,
          color: showRedBackground
              ? Colors.white
              : (isActive ? const Color(0xFFEF484F) : const Color(0xFF46090C)),
          size: showRedBackground ? 26 : 24,
        ),
      ),
    );
  }
}