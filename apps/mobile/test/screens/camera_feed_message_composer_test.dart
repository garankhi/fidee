import 'package:fidey_mobile/screens/camera_feed_message_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows message placeholder and reaction shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CameraFeedMessageComposer()),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('camera-feed-message-composer')),
      findsOneWidget,
    );
    expect(find.text('Gửi tin nhắn...'), findsOneWidget);
    expect(find.text('🏅'), findsOneWidget);
    expect(find.text('🎾'), findsOneWidget);
    expect(find.text('😋'), findsOneWidget);
    expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget);
  });

  testWidgets('accepts local text entry without sending network requests', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CameraFeedMessageComposer()),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('camera-feed-message-field')),
      'Hay quá',
    );
    await tester.pump();

    expect(find.text('Hay quá'), findsOneWidget);
  });

  testWidgets('submits text through callback and clears the field', (
    tester,
  ) async {
    String? sentMessage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraFeedMessageComposer(
              onSend: (message) => sentMessage = message,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('camera-feed-message-field')),
      'Hay quá',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(sentMessage, 'Hay quá');
    expect(find.text('Hay quá'), findsNothing);
  });

  testWidgets('sends reaction shortcuts through callback', (tester) async {
    String? sentReaction;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraFeedMessageComposer(
              onReaction: (reaction) => sentReaction = reaction,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('🎾'));
    await tester.pump();

    expect(sentReaction, '🎾');
  });
}
