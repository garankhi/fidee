import 'package:fidee_mobile/screens/camera_feed_action_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows capture controls while viewing the live camera', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: CameraFeedActionArea(
            isViewingFeed: false,
            captureControls: Text('Capture controls'),
            messageComposer: Text('Message composer'),
          ),
        ),
      ),
    );

    expect(find.text('Capture controls'), findsOneWidget);
    expect(find.text('Message composer'), findsNothing);
  });

  testWidgets('replaces capture controls with message composer in feed mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: CameraFeedActionArea(
            isViewingFeed: true,
            captureControls: Text('Capture controls'),
            messageComposer: Text('Message composer'),
          ),
        ),
      ),
    );

    expect(find.text('Capture controls'), findsNothing);
    expect(find.text('Message composer'), findsOneWidget);
  });

  testWidgets('hides message composer when feed has no friend image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: CameraFeedActionArea(
            isViewingFeed: true,
            hasFeedItem: false,
            captureControls: Text('Capture controls'),
            messageComposer: Text('Message composer'),
          ),
        ),
      ),
    );

    expect(find.text('Capture controls'), findsNothing);
    expect(find.text('Message composer'), findsNothing);
    expect(find.byKey(const ValueKey('camera-feed-empty-action-area')), findsOneWidget);
  });
}
