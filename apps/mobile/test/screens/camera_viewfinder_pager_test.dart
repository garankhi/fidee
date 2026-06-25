import 'package:fidey_mobile/models/camera_checkin_feed_item.dart';
import 'package:fidey_mobile/screens/camera_viewfinder_pager.dart';
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
              cameraControls: const Text(
                'Capture controls',
                key: ValueKey('fake-camera-controls'),
              ),
              feedItems: const <CameraCheckinFeedItem>[item],
              isFeedLoading: false,
              isFeedLoadingMore: false,
              hasMore: false,
              onLoadMore: _noop,
              onFeedItemChanged: (item) => activeItem = item,
              feedMessageComposerBuilder: (item) => const Text(
                'Message composer',
                key: ValueKey('fake-message-composer'),
              ),
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
      find.byKey(const ValueKey('camera-feed-swipe-page-checkin-1')),
      findsOneWidget,
    );
    expect(find.text('Nó vẫn chưa tha'), findsOneWidget);
    expect(activeItem?.id, 'checkin-1');
  });

  testWidgets(
    'drags feed photo frame and message composer upward as one page',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: SizedBox(
                width: 360,
                height: 620,
                child: CameraViewfinderPager(
                  cameraPreview: const ColoredBox(
                    key: ValueKey('fake-camera-preview'),
                    color: Colors.red,
                  ),
                  cameraOverlay: const SizedBox.shrink(),
                  cameraControls: const Text(
                    'Capture controls',
                    key: ValueKey('fake-camera-controls'),
                  ),
                  feedItems: const <CameraCheckinFeedItem>[item],
                  isFeedLoading: false,
                  isFeedLoadingMore: false,
                  hasMore: false,
                  onLoadMore: _noop,
                  onFeedItemChanged: _ignoreItem,
                  feedMessageComposerBuilder: (item) => const Text(
                    'Message composer',
                    key: ValueKey('fake-message-composer'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final feedPageFinder = find.byKey(
        const ValueKey('camera-feed-swipe-page-checkin-1'),
      );
      final composerFinder = find.byKey(
        const ValueKey('fake-message-composer'),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('camera-viewfinder-pager'))),
      );
      await gesture.moveBy(const Offset(0, -180));
      await tester.pump();

      final pageTopAfterFirstDrag = tester.getTopLeft(feedPageFinder).dy;
      final composerTopAfterFirstDrag = tester.getTopLeft(composerFinder).dy;

      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();

      final pageTopAfterSecondDrag = tester.getTopLeft(feedPageFinder).dy;
      final composerTopAfterSecondDrag = tester.getTopLeft(composerFinder).dy;
      await gesture.up();

      expect(pageTopAfterSecondDrag, lessThan(pageTopAfterFirstDrag));
      expect(composerTopAfterSecondDrag, lessThan(composerTopAfterFirstDrag));
      expect(
        composerTopAfterSecondDrag - pageTopAfterSecondDrag,
        moreOrLessEquals(
          composerTopAfterFirstDrag - pageTopAfterFirstDrag,
          epsilon: 1,
        ),
      );
    },
  );

  testWidgets('shows inline feed skeleton inside viewfinder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraViewfinderPager(
              cameraPreview: ColoredBox(color: Colors.red),
              cameraOverlay: SizedBox.shrink(),
              cameraControls: Text(
                'Capture controls',
                key: ValueKey('fake-camera-controls'),
              ),
              feedItems: <CameraCheckinFeedItem>[],
              isFeedLoading: true,
              isFeedLoadingMore: false,
              hasMore: false,
              onLoadMore: _noop,
              onFeedItemChanged: _ignoreItem,
              feedMessageComposerBuilder: _fakeComposerBuilder,
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
              cameraControls: const Text(
                'Capture controls',
                key: ValueKey('fake-camera-controls'),
              ),
              feedItems: const <CameraCheckinFeedItem>[],
              isFeedLoading: true,
              isFeedLoadingMore: false,
              hasMore: false,
              onLoadMore: _noop,
              onFeedItemChanged: _ignoreItem,
              onFeedModeChanged: (value) => isViewingFeed = value,
              feedMessageComposerBuilder: _fakeComposerBuilder,
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(isViewingFeed, isTrue);
  });

  testWidgets('reports feed mode when feed page starts to appear during drag', (
    tester,
  ) async {
    var isViewingFeed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: SizedBox(
              width: 360,
              height: 620,
              child: CameraViewfinderPager(
                cameraPreview: const ColoredBox(color: Colors.red),
                cameraOverlay: const SizedBox.shrink(),
                cameraControls: const Text('Capture controls'),
                feedItems: const <CameraCheckinFeedItem>[item],
                isFeedLoading: false,
                isFeedLoadingMore: false,
                hasMore: false,
                onLoadMore: _noop,
                onFeedItemChanged: _ignoreItem,
                onFeedModeChanged: (value) => isViewingFeed = value,
                feedMessageComposerBuilder: _fakeComposerBuilder,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('camera-viewfinder-pager'))),
    );
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();

    expect(isViewingFeed, isTrue);

    await gesture.up();
  });
}

Future<void> _noop() async {}
void _ignoreItem(CameraCheckinFeedItem? item) {}
Widget _fakeComposerBuilder(CameraCheckinFeedItem item) =>
    const Text('Message composer', key: ValueKey('fake-message-composer'));
