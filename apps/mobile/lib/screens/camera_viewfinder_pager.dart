import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/camera_checkin_feed_item.dart';
import '../services/camera_feed_image_cache.dart';
import 'camera_checkin_feed.dart';

class CameraViewfinderPager extends StatefulWidget {
  final Widget cameraPreview;
  final Widget cameraOverlay;
  final Widget cameraControls;
  final List<CameraCheckinFeedItem> feedItems;
  final bool isFeedLoading;
  final bool isFeedLoadingMore;
  final bool hasMore;
  final Future<void> Function() onLoadMore;
  final ValueChanged<CameraCheckinFeedItem?> onFeedItemChanged;
  final ValueChanged<bool>? onFeedModeChanged;
  final Widget Function(CameraCheckinFeedItem item) feedMessageComposerBuilder;
  final PageController? pageController;

  const CameraViewfinderPager({
    super.key,
    required this.cameraPreview,
    required this.cameraOverlay,
    required this.cameraControls,
    required this.feedItems,
    required this.isFeedLoading,
    required this.isFeedLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.onFeedItemChanged,
    required this.feedMessageComposerBuilder,
    this.onFeedModeChanged,
    this.pageController,
  });

  @override
  State<CameraViewfinderPager> createState() => _CameraViewfinderPagerState();
}

class _CameraViewfinderPagerState extends State<CameraViewfinderPager> {
  late final PageController _pageController;
  final Set<String> _prefetchedCacheKeys = <String>{};
  bool _lastReportedFeedMode = false;

  @override
  void initState() {
    super.initState();
    _pageController = widget.pageController ?? PageController();
    _pageController.addListener(_handlePageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageScroll);
    if (widget.pageController == null) {
      _pageController.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CameraViewfinderPager oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.feedItems != widget.feedItems) {
      _prefetchUpcomingFeedImages(_currentFeedItem());
    }
  }

  CameraCheckinFeedItem? _currentFeedItem() {
    if (!_pageController.hasClients) return null;

    final page =
        (_pageController.page ?? _pageController.initialPage.toDouble())
            .round();
    final feedIndex = page - 1;
    if (feedIndex < 0 || feedIndex >= widget.feedItems.length) return null;
    return widget.feedItems[feedIndex];
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? _pageController.initialPage.toDouble();
    _emitFeedMode(page > 0.08);
  }

  void _emitFeedMode(bool value) {
    if (_lastReportedFeedMode == value) return;
    _lastReportedFeedMode = value;
    widget.onFeedModeChanged?.call(value);
  }

  void _onPageChanged(int index) {
    _emitFeedMode(index > 0);

    if (index == 0) {
      widget.onFeedItemChanged(null);
      _prefetchUpcomingFeedImages(null);
      return;
    }

    final feedIndex = index - 1;
    final item = feedIndex < widget.feedItems.length
        ? widget.feedItems[feedIndex]
        : null;
    widget.onFeedItemChanged(item);
    _prefetchUpcomingFeedImages(item);

    if (widget.hasMore &&
        !widget.isFeedLoadingMore &&
        feedIndex >= widget.feedItems.length - 2) {
      unawaited(widget.onLoadMore());
    }
  }

  void _prefetchUpcomingFeedImages(CameraCheckinFeedItem? activeItem) {
    final diskItems = nextCameraFeedDiskPrefetchItems(
      items: widget.feedItems,
      activeItem: activeItem,
    );

    for (final item in diskItems) {
      final cacheKey = cameraFeedImageCacheKey(item);
      if (!_prefetchedCacheKeys.add(cacheKey)) continue;
      unawaited(_prefetchDiskImage(item, cacheKey));
    }

    final memoryItems = nextCameraFeedMemoryPrecacheItems(
      items: widget.feedItems,
      activeItem: activeItem,
    );

    for (final item in memoryItems) {
      unawaited(_precacheMemoryImage(item));
    }
  }

  Future<void> _prefetchDiskImage(
    CameraCheckinFeedItem item,
    String cacheKey,
  ) async {
    try {
      await CameraFeedImageCacheManager.instance.downloadFile(
        item.imageUrl,
        key: cacheKey,
      );
    } catch (_) {
      // Prefetch is opportunistic; failed image fetches should not break camera UI.
    }
  }

  Future<void> _precacheMemoryImage(CameraCheckinFeedItem item) async {
    if (!mounted) return;

    try {
      final cacheKey = cameraFeedImageCacheKey(item);
      await precacheImage(
        CachedNetworkImageProvider(
          item.imageUrl,
          cacheKey: cacheKey,
          cacheManager: CameraFeedImageCacheManager.instance,
        ),
        context,
      );
    } catch (_) {
      // Memory pre-cache is opportunistic for smoother swipes only.
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedPageCount = widget.isFeedLoading && widget.feedItems.isEmpty
        ? 1
        : widget.feedItems.isEmpty
        ? 1
        : widget.feedItems.length;

    return PageView.builder(
      key: const ValueKey('camera-viewfinder-pager'),
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemCount: 1 + feedPageCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CameraSwipePage(
            key: const ValueKey('camera-viewfinder-page-camera'),
            media: _RoundedMediaFrame(
              aspectRatio: 1,
              borderRadius: 40,
              child: Stack(
                fit: StackFit.expand,
                children: [widget.cameraPreview, widget.cameraOverlay],
              ),
            ),
            footer: widget.cameraControls,
          );
        }

        if (widget.isFeedLoading && widget.feedItems.isEmpty) {
          return const _CameraSwipePage(
            key: ValueKey('camera-viewfinder-feed-skeleton-page'),
            media: _RoundedMediaFrame(child: _ViewfinderFeedSkeleton()),
            footer: SizedBox(height: 96),
          );
        }

        if (widget.feedItems.isEmpty) {
          return const _CameraSwipePage(
            key: ValueKey('camera-viewfinder-feed-empty-page'),
            media: _RoundedMediaFrame(child: _ViewfinderFeedEmptyState()),
            footer: SizedBox(height: 96),
          );
        }

        final item = widget.feedItems[index - 1];
        return _FeedSwipePage(
          key: ValueKey('camera-feed-swipe-page-${item.id}'),
          item: item,
          messageComposer: widget.feedMessageComposerBuilder(item),
        );
      },
    );
  }
}

class _CameraSwipePage extends StatelessWidget {
  final Widget media;
  final Widget footer;

  const _CameraSwipePage({
    super.key,
    required this.media,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 620;
        const horizontalPadding = 16.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: [
              Expanded(
                child: Align(alignment: Alignment.bottomCenter, child: media),
              ),
              SizedBox(height: compactHeight ? 10 : 16),
              footer,
            ],
          ),
        );
      },
    );
  }
}

class _FeedSwipePage extends StatelessWidget {
  final CameraCheckinFeedItem item;
  final Widget messageComposer;

  const _FeedSwipePage({
    super.key,
    required this.item,
    required this.messageComposer,
  });

  @override
  Widget build(BuildContext context) {
    return _CameraSwipePage(
      media: _RoundedMediaFrame(
        child: ColoredBox(
          color: Colors.black,
          child: CameraFeedPhotoFrame(item: item),
        ),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CameraFeedAuthorMeta(item: item),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: ValueKey('camera-feed-message-composer-${item.id}'),
            child: messageComposer,
          ),
        ],
      ),
    );
  }
}

class _RoundedMediaFrame extends StatelessWidget {
  final Widget child;
  final double aspectRatio;
  final double borderRadius;

  const _RoundedMediaFrame({
    required this.child,
    this.aspectRatio = 3 / 4,
    this.borderRadius = 30,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final width = maxWidth.clamp(0.0, maxHeight * aspectRatio);
        final height = width / aspectRatio;

        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: child,
          ),
        );
      },
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
