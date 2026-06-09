import 'package:fidee_mobile/models/camera_checkin_feed_item.dart';
import 'package:fidee_mobile/screens/camera_viewfinder_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const item = CameraCheckinFeedItem(
    id: 'checkin-1',
    caption: 'Nó vẫn chưa tha',
    createdAt: '2026-06-09T14:48:00.000Z',
    mediaId: 'media-1',
    userId: 'friend-1',
    userName: 'Tạ',
    placeId: 'place-1',
    placeName: 'Sân cầu lông',
  );

  testWidgets('starts on camera page then swipes to feed item', (tester) async {
    CameraCheckinFeedItem? activeItem;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraViewfinderPager(
              cameraPreview: const ColoredBox(
                key: ValueKey('fake-camera-preview'),
                color: Colors.red,
              ),
              cameraOverlay: const SizedBox.shrink(),
              feedItems: const <CameraCheckinFeedItem>[item],
              isFeedLoading: false,
              isFeedLoadingMore: false,
              hasMore: false,
              onLoadMore: _noop,
              onFeedItemChanged: (item) => activeItem = item,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('camera-viewfinder-page-camera')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('fake-camera-preview')), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('camera-viewfinder-page-feed-checkin-1')),
      findsOneWidget,
    );
    expect(find.text('Nó vẫn chưa tha'), findsOneWidget);
    expect(activeItem?.id, 'checkin-1');
  });

  testWidgets('shows inline feed skeleton inside viewfinder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraViewfinderPager(
              cameraPreview: ColoredBox(color: Colors.red),
              cameraOverlay: SizedBox.shrink(),
              feedItems: <CameraCheckinFeedItem>[],
              isFeedLoading: true,
              isFeedLoadingMore: false,
              hasMore: false,
              onLoadMore: _noop,
              onFeedItemChanged: _ignoreItem,
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('camera-viewfinder-feed-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('reports feed mode even when feed page only has skeleton', (
    tester,
  ) async {
    var isViewingFeed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraViewfinderPager(
              cameraPreview: const ColoredBox(color: Colors.red),
              cameraOverlay: const SizedBox.shrink(),
              feedItems: const <CameraCheckinFeedItem>[],
              isFeedLoading: true,
              isFeedLoadingMore: false,
              hasMore: false,
              onLoadMore: _noop,
              onFeedItemChanged: _ignoreItem,
              onFeedModeChanged: (value) => isViewingFeed = value,
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(isViewingFeed, isTrue);
  });
}

Future<void> _noop() async {}
void _ignoreItem(CameraCheckinFeedItem? item) {}
