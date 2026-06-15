import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final String? userAvatarUrl;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.userAvatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildNavItem(index: 0, label: 'Khám phá', icon: Icons.explore)),
          Expanded(child: _buildNavItem(index: 1, label: 'Bảng tin', icon: Icons.layers)),
          Expanded(child: _buildNavItem(index: 2, label: 'Nhật ký', icon: Icons.move_to_inbox)),
          Expanded(child: _buildNavItem(index: 3, label: 'Cá nhân', isAvatar: true)),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    IconData? icon,
    bool isAvatar = false,
  }) {
    final bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: isActive
            ? const BoxDecoration(
          color: Color(0xFFEF484F),
        )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: isAvatar
                  ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? Colors.white : Colors.transparent,
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
                    ? Center(
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: isActive ? Colors.white : Colors.black,
                  ),
                )
                    : null,
              )
                  : Icon(
                icon,
                size: 22,
                color: isActive ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black,
                fontSize: 12,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}