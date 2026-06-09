import 'package:flutter/material.dart';

class CameraFeedActionArea extends StatelessWidget {
  final bool isViewingFeed;
  final bool hasFeedItem;
  final Widget captureControls;
  final Widget messageComposer;

  const CameraFeedActionArea({
    super.key,
    required this.isViewingFeed,
    this.hasFeedItem = true,
    required this.captureControls,
    required this.messageComposer,
  });

  @override
  Widget build(BuildContext context) {
    final child = switch ((isViewingFeed, hasFeedItem)) {
      (false, _) => captureControls,
      (true, true) => messageComposer,
      (true, false) => const SizedBox(
          key: ValueKey('camera-feed-empty-action-area'),
          height: 112,
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: child,
    );
  }
}
