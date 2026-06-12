import 'package:fidee_mobile/models/camera_checkin_feed_item.dart';
import 'package:fidee_mobile/screens/camera_checkin_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows inline skeleton without fullscreen spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: CameraCheckinFeedView(
            items: <CameraCheckinFeedItem>[],
            isLoading: true,
            isLoadingMore: false,
            hasMore: false,
            onRefresh: _noop,
            onLoadMore: _noop,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('camera-checkin-feed-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders image card with caption and relative time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: CameraCheckinFeedView(
            items: const <CameraCheckinFeedItem>[
              CameraCheckinFeedItem(
                id: 'checkin-1',
                caption: 't bi ghiền r',
                createdAt: '2026-06-09T08:30:00.000Z',
                mediaId: 'media-1',
                userId: 'friend-1',
                userName: 'ahn',
                placeId: 'place-1',
                placeName: 'Rice & Curry',
              ),
            ],
            isLoading: false,
            isLoadingMore: false,
            hasMore: false,
            now: DateTime.parse('2026-06-09T21:30:00.000Z'),
            onRefresh: _noop,
            onLoadMore: _noop,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('camera-checkin-card-checkin-1')),
      findsOneWidget,
    );
    expect(find.text('t bi ghiền r'), findsOneWidget);
    expect(find.text('13g'), findsOneWidget);
  });

  testWidgets('shows empty state when no check-ins exist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: CameraCheckinFeedView(
            items: <CameraCheckinFeedItem>[],
            isLoading: false,
            isLoadingMore: false,
            hasMore: false,
            onRefresh: _noop,
            onLoadMore: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Chưa có ảnh check-in từ bạn bè'), findsOneWidget);
  });

  testWidgets('camera feed photo frame renders caption inside rounded image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraFeedPhotoFrame(
              item: CameraCheckinFeedItem(
                id: 'checkin-2',
                caption: 'Nó vẫn chưa tha',
                createdAt: '2026-06-09T14:48:00.000Z',
                mediaId: 'media-2',
                userId: 'friend-2',
                userName: 'Tạ',
                placeId: 'place-2',
                placeName: 'Sân cầu lông',
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('camera-feed-photo-frame-checkin-2')),
      findsOneWidget,
    );
    expect(find.text('Nó vẫn chưa tha'), findsOneWidget);
  });

  testWidgets('camera feed author meta shows user and relative time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: CameraFeedAuthorMeta(
            item: const CameraCheckinFeedItem(
              id: 'checkin-3',
              createdAt: '2026-06-09T14:48:00.000Z',
              mediaId: 'media-3',
              userId: 'friend-3',
              userName: 'Tạ',
              placeId: 'place-3',
              placeName: 'Sân cầu lông',
            ),
            now: DateTime.parse('2026-06-09T15:17:00.000Z'),
          ),
        ),
      ),
    );

    expect(find.text('Tạ'), findsOneWidget);
    expect(find.text('29p'), findsOneWidget);
  });
}

Future<void> _noop() async {}
