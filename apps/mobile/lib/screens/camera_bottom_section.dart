import 'package:flutter/material.dart';

enum CameraBottomTab { history, home, chat }

class CameraBottomSection extends StatelessWidget {
  final VoidCallback? onHomeTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onHistoryLabelTap;
  final CameraBottomTab activeTab;
  final bool showHistory;
  final bool showHomeAsShutter;
  final int unreadCount;

  const CameraBottomSection({
    super.key,
    this.onHomeTap,
    this.onChatTap,
    this.onHistoryTap,
    this.onHistoryLabelTap,
    this.activeTab = CameraBottomTab.home,
    this.showHistory = true,
    this.showHomeAsShutter = false,
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
          GestureDetector(
            onTap: onHistoryLabelTap ?? onHistoryTap,
            child: Container(
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
              GestureDetector(
                onTap: onHistoryTap,
                child: Container(
                  key: const ValueKey('camera-bottom-history-button'),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activeTab == CameraBottomTab.history
                        ? Colors.grey[800]
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: activeTab == CameraBottomTab.history
                        ? Colors.white
                        : Colors.grey,
                    size: 24,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onHomeTap,
                child: Container(
                  key: const ValueKey('camera-bottom-home-button'),
                  padding: EdgeInsets.all(showHomeAsShutter ? 3 : 8),
                  decoration: BoxDecoration(
                    color:
                        activeTab == CameraBottomTab.home && !showHomeAsShutter
                        ? Colors.grey[800]
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: showHomeAsShutter
                      ? const _CameraBottomShutterButton()
                      : Icon(
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

class _CameraBottomShutterButton extends StatelessWidget {
  const _CameraBottomShutterButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFEF484F), width: 3),
      ),
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
