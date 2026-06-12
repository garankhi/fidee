import 'dart:async';

import 'package:flutter/material.dart';

import '../models/camera_checkin_feed_item.dart';
import 'camera_checkin_feed.dart';

class CameraViewfinderPager extends StatefulWidget {
  final Widget cameraPreview;
  final Widget cameraOverlay;
  final List<CameraCheckinFeedItem> feedItems;
  final bool isFeedLoading;
  final bool isFeedLoadingMore;
  final bool hasMore;
  final Future<void> Function() onLoadMore;
  final ValueChanged<CameraCheckinFeedItem?> onFeedItemChanged;
  final ValueChanged<bool>? onFeedModeChanged;

  const CameraViewfinderPager({
    super.key,
    required this.cameraPreview,
    required this.cameraOverlay,
    required this.feedItems,
    required this.isFeedLoading,
    required this.isFeedLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.onFeedItemChanged,
    this.onFeedModeChanged,
  });

  @override
  State<CameraViewfinderPager> createState() => _CameraViewfinderPagerState();
}

class _CameraViewfinderPagerState extends State<CameraViewfinderPager> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    widget.onFeedModeChanged?.call(index > 0);

    if (index == 0) {
      widget.onFeedItemChanged(null);
      return;
    }

    final feedIndex = index - 1;
    final item = feedIndex < widget.feedItems.length
        ? widget.feedItems[feedIndex]
        : null;
    widget.onFeedItemChanged(item);

    if (widget.hasMore &&
        !widget.isFeedLoadingMore &&
        feedIndex >= widget.feedItems.length - 2) {
      unawaited(widget.onLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedPageCount = widget.isFeedLoading && widget.feedItems.isEmpty
        ? 1
        : widget.feedItems.isEmpty
        ? 1
        : widget.feedItems.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        onPageChanged: _onPageChanged,
        itemCount: 1 + feedPageCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Stack(
              key: const ValueKey('camera-viewfinder-page-camera'),
              fit: StackFit.expand,
              children: [widget.cameraPreview, widget.cameraOverlay],
            );
          }

          if (widget.isFeedLoading && widget.feedItems.isEmpty) {
            return const _ViewfinderFeedSkeleton();
          }

          if (widget.feedItems.isEmpty) {
            return const _ViewfinderFeedEmptyState();
          }

          final item = widget.feedItems[index - 1];
          return ColoredBox(
            key: ValueKey('camera-viewfinder-page-feed-${item.id}'),
            color: Colors.black,
            child: CameraFeedPhotoFrame(item: item),
          );
        },
      ),
    );
  }
}

class _ViewfinderFeedSkeleton extends StatelessWidget {
  const _ViewfinderFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('camera-viewfinder-feed-skeleton'),
      decoration: const BoxDecoration(color: Color(0xFF171717)),
      child: Center(
        child: Container(
          width: 120,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(9),
          ),
        ),
      ),
    );
  }
}

class _ViewfinderFeedEmptyState extends StatelessWidget {
  const _ViewfinderFeedEmptyState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF171717),
      child: Center(
        child: Text(
          'Chưa có ảnh từ bạn bè',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
