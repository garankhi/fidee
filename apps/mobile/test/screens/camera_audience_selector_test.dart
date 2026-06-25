import 'package:fidey_mobile/models/camera_checkin_feed_item.dart';
import 'package:fidey_mobile/screens/camera_audience_selector.dart';
import 'package:fidey_mobile/services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows current audience pill and opens dropdown', (tester) async {
    CameraFeedAudience? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraAudienceSelector(
              selectedAudience: CameraFeedAudience.everyone(),
              friends: const <FriendProfile>[
                FriendProfile(id: 'friend-1', name: 'ahn', handle: 'ahn'),
              ],
              onSelected: (audience) => selected = audience,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mọi người'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('camera-audience-pill')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('camera-audience-dropdown')),
      findsOneWidget,
    );
    expect(find.text('Bạn'), findsOneWidget);
    expect(find.text('ahn'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('camera-audience-friend-friend-1')),
    );
    await tester.pumpAndSettle();

    expect(selected?.type, CameraFeedAudienceType.friend);
    expect(selected?.id, 'friend-1');
  });

  testWidgets('animates chevron upward when dropdown opens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraAudienceSelector(
              selectedAudience: CameraFeedAudience.everyone(),
              friends: const <FriendProfile>[],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    AnimatedRotation rotation = tester.widget<AnimatedRotation>(
      find.byKey(const ValueKey('camera-audience-chevron')),
    );
    expect(rotation.turns, 0);

    await tester.tap(find.byKey(const ValueKey('camera-audience-pill')));
    await tester.pump(const Duration(milliseconds: 90));

    rotation = tester.widget<AnimatedRotation>(
      find.byKey(const ValueKey('camera-audience-chevron')),
    );
    expect(rotation.turns, 0.5);
  });

  testWidgets('renders friend avatar image in dropdown rows', (tester) async {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('HTTP request failed')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraAudienceSelector(
              selectedAudience: CameraFeedAudience.everyone(),
              friends: const <FriendProfile>[
                FriendProfile(
                  id: 'friend-1',
                  name: 'Quang',
                  handle: 'quang',
                  avatarUrl: 'https://example.com/quang.jpg',
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('camera-audience-pill')));
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const ValueKey('camera-audience-avatar-friend-1')),
    );
    expect(avatar.backgroundImage, isA<NetworkImage>());
    expect(find.text('Quang'), findsOneWidget);
  });

  testWidgets('shows selected friend name in closed pill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraAudienceSelector(
              selectedAudience: CameraFeedAudience.friend(
                id: 'friend-1',
                label: 'Quang',
                avatarUrl: 'https://example.com/quang.jpg',
              ),
              friends: const <FriendProfile>[
                FriendProfile(
                  id: 'friend-1',
                  name: 'Quang',
                  handle: 'quang',
                  avatarUrl: 'https://example.com/quang.jpg',
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Quang'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('camera-audience-dropdown')),
      findsNothing,
    );
  });
}
