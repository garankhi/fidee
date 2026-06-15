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

  static const _kRadius = Radius.circular(20);
  static const _kPillRadius = BorderRadius.all(Radius.circular(14));
  static const _kActiveColor = Color(0xFFEF484F);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: _kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            spreadRadius: 2,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildNavItem(index: 0, label: 'Khám phá', icon: Icons.explore)),
                Expanded(child: _buildNavItem(index: 1, label: 'Bảng tin', icon: Icons.layers)),
                Expanded(child: _buildNavItem(index: 2, label: 'Nhật ký', icon: Icons.move_to_inbox)),
                Expanded(child: _buildNavItem(index: 3, label: 'Cá nhân', isAvatar: true)),
              ],
            ),
          ),
        ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: _kPillRadius,
        splashColor: _kActiveColor.withOpacity(0.15),
        highlightColor: _kActiveColor.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? _kActiveColor : Colors.transparent,
              borderRadius: _kPillRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
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
                                    color: isActive ? Colors.white : Colors.black54,
                                  ),
                                )
                              : null,
                        )
                      : Icon(
                          icon,
                          size: 22,
                          color: isActive ? Colors.white : Colors.black54,
                        ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.black54,
                    fontSize: 11,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}