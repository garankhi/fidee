import 'package:flutter/material.dart';

enum CameraBottomTab { home, chat }

class CameraBottomSection extends StatelessWidget {
  final VoidCallback? onHomeTap;
  final VoidCallback? onChatTap;
  final CameraBottomTab activeTab;
  final bool showHistory;
  final int unreadCount;

  const CameraBottomSection({
    super.key,
    this.onHomeTap,
    this.onChatTap,
    this.activeTab = CameraBottomTab.home,
    this.showHistory = true,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('camera-bottom-section'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showHistory) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[700],
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Lịch sử',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.grey,
                  size: 28,
                ),
                GestureDetector(
                  onTap: onHomeTap,
                  child: Container(
                    key: const ValueKey('camera-bottom-home-button'),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activeTab == CameraBottomTab.home
                          ? Colors.grey[800]
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.home_filled,
                      color: activeTab == CameraBottomTab.home
                          ? Colors.white
                          : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('camera-bottom-chat-button'),
                  onTap: onChatTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: activeTab == CameraBottomTab.chat
                              ? Colors.grey[800]
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: activeTab == CameraBottomTab.chat
                              ? Colors.white
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
      ],
    );
  }
}
