import 'package:flutter/material.dart';

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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
              decoration: ShapeDecoration(
                color: const Color(0xA8E78B8B),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    width: 0.8,
                    strokeAlign: BorderSide.strokeAlignOutside,
                    color: Color(0xFFEF484F),
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildNavItem(
                      Icons.layers,
                      currentIndex == 0,
                      () => onTap(0),
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      Icons.explore,
                      currentIndex == 1,
                      () => onTap(1),
                      isCenterActive: true,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      Icons.move_to_inbox,
                      currentIndex == 2,
                      () => onTap(2),
                    ),
                  ),
                  Expanded(child: _buildAvatarNavItem(currentIndex == 3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    bool isActive,
    VoidCallback onTap, {
    bool isCenterActive = false,
  }) {
    final bool showRedBackground = isActive && isCenterActive;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Container(
          height: double.infinity,
          decoration: ShapeDecoration(
            color: showRedBackground
                ? const Color(0xFFEF484F)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(33),
            ),
          ),
          child: Icon(
            icon,
            color: showRedBackground
                ? Colors.white
                : (isActive
                      ? const Color(0xFFEF484F)
                      : const Color(0xFF46090C)),
            size: showRedBackground ? 26 : 24,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarNavItem(bool isActive) {
    return GestureDetector(
      onTap: () => onTap(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD4DA),
              border: Border.all(
                color: isActive ? const Color(0xFFEF484F) : Colors.white,
                width: 1.5,
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
                    child: Icon(
                      Icons.person,
                      size: 18,
                      color: Color(0xFFEF484F),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
