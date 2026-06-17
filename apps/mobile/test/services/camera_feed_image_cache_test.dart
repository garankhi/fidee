import 'package:fidee_mobile/models/camera_checkin_feed_item.dart';
import 'package:fidee_mobile/services/camera_feed_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final items = List<CameraCheckinFeedItem>.generate(
    5,
    (index) => CameraCheckinFeedItem(
      id: 'checkin-$index',
      caption: 'Caption $index',
      createdAt: '2026-06-12T01:0$index:00.000Z',
      mediaId: 'media-$index',
      userId: 'friend-$index',
      userName: 'Friend $index',
      placeId: 'place-$index',
      placeName: 'Place $index',
    ),
  );

  test('uses media id as stable cache key', () {
    expect(cameraFeedImageCacheKey(items.first), 'media-0');
  });

  test('falls back to image URL when media id is unavailable', () {
    const item = CameraCheckinFeedItem(
      id: 'checkin-without-media',
      createdAt: '2026-06-12T01:00:00.000Z',
      userId: 'friend-0',
      userName: 'Friend 0',
      placeId: 'place-0',
      placeName: 'Place 0',
    );

    expect(cameraFeedImageCacheKey(item), item.imageUrl);
  });

  test('disk prefetch starts at first feed item while user is on camera page', () {
    final nextItems = nextCameraFeedDiskPrefetchItems(
      items: items,
      activeItem: null,
    );

    expect(nextItems.map((item) => item.id), [
      'checkin-0',
      'checkin-1',
      'checkin-2',
    ]);
  });

  test('disk prefetch selects N+1 through N+3 for the active feed item', () {
    final nextItems = nextCameraFeedDiskPrefetchItems(
      items: items,
      activeItem: items[1],
    );

    expect(nextItems.map((item) => item.id), [
      'checkin-2',
      'checkin-3',
      'checkin-4',
    ]);
  });

  test('prefetch helpers skip video items', () {
    final mixedItems = <CameraCheckinFeedItem>[
      items[0],
      const CameraCheckinFeedItem(
        id: 'checkin-video',
        createdAt: '2026-06-12T01:02:00.000Z',
        mediaId: 'video-1',
        mediaType: CameraCheckinMediaType.video,
        userId: 'friend-video',
        userName: 'Friend Video',
        placeId: 'place-video',
        placeName: 'Place Video',
      ),
      items[1],
    ];

    final nextItems = nextCameraFeedDiskPrefetchItems(
      items: mixedItems,
      activeItem: null,
    );

    expect(nextItems.map((item) => item.id), ['checkin-0', 'checkin-1']);
  });

  test('memory precache is intentionally narrower than disk prefetch', () {
    final nextItems = nextCameraFeedMemoryPrecacheItems(
      items: items,
      activeItem: items[1],
    );

    expect(nextItems.map((item) => item.id), ['checkin-2']);
  });
}
