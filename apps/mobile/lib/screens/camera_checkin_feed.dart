import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/camera_checkin_feed_provider.dart';
import '../models/camera_checkin_feed_item.dart';
import '../services/camera_feed_image_cache.dart';

class CameraCheckinFeed extends ConsumerWidget {
  const CameraCheckinFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraCheckinFeedControllerProvider);
    final controller = ref.read(cameraCheckinFeedControllerProvider.notifier);

    return CameraCheckinFeedView(
      items: state.items,
      isLoading: state.isLoading,
      isLoadingMore: state.isLoadingMore,
      hasMore: state.hasMore,
      scrollable: false,
      onRefresh: controller.refresh,
      onLoadMore: controller.loadMore,
    );
  }
}

class CameraCheckinFeedView extends StatelessWidget {
  final List<CameraCheckinFeedItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool scrollable;
  final DateTime? now;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  const CameraCheckinFeedView({
    super.key,
    required this.items,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    this.scrollable = true,
    this.now,
    required this.onRefresh,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FeedHeader(onRefresh: onRefresh),
          const SizedBox(height: 18),
          if (isLoading && items.isEmpty)
            const _CameraFeedSkeleton()
          else if (items.isEmpty)
            const _CameraFeedEmptyState()
          else ...[
            for (final item in items) ...[
              _CameraCheckinCard(item: item, now: now),
              const SizedBox(height: 26),
            ],
            if (isLoadingMore)
              const _InlineLoadMoreIndicator()
            else if (hasMore)
              TextButton(
                onPressed: onLoadMore,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Xem thêm'),
              ),
          ],
        ],
      ),
    );

    if (!scrollable) return content;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: content,
    );
  }
}

class _FeedHeader extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _FeedHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Check-in gần đây',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          tooltip: 'Tải lại feed',
        ),
      ],
    );
  }
}

class _CameraFeedSkeleton extends StatelessWidget {
  const _CameraFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('camera-checkin-feed-skeleton'),
      children: List<Widget>.generate(
        2,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 0.82,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFF242424),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 56,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraFeedEmptyState extends StatelessWidget {
  const _CameraFeedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Text(
        'Chưa có ảnh check-in từ bạn bè',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.64),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CameraCheckinCard extends StatelessWidget {
  final CameraCheckinFeedItem item;
  final DateTime? now;

  const _CameraCheckinCard({required this.item, this.now});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('camera-checkin-card-${item.id}'),
      children: [
        CameraFeedPhotoFrame(item: item),
        const SizedBox(height: 18),
        CameraFeedAuthorMeta(item: item, now: now),
      ],
    );
  }
}

class CameraFeedPhotoFrame extends StatelessWidget {
  final CameraCheckinFeedItem item;

  const CameraFeedPhotoFrame({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final caption = item.caption?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          key: ValueKey('camera-feed-photo-frame-${item.id}'),
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.imageUrl,
              cacheManager: CameraFeedImageCacheManager.instance,
              cacheKey: cameraFeedImageCacheKey(item),
              fit: BoxFit.cover,
              placeholder: (context, url) {
                return const ColoredBox(color: Color(0xFF171717));
              },
              errorWidget: (context, url, error) {
                return const ColoredBox(
                  color: Color(0xFF2A2A2A),
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 36,
                    ),
                  ),
                );
              },
            ),
            if (caption.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 22,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CameraFeedAuthorMeta extends StatelessWidget {
  final CameraCheckinFeedItem item;
  final DateTime? now;

  const CameraFeedAuthorMeta({super.key, required this.item, this.now});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            item.userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          item.relativeTime(now: now),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.64),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _InlineLoadMoreIndicator extends StatelessWidget {
  const _InlineLoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        'Đang tải thêm...',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.58),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
