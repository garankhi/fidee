import 'package:fidee_mobile/screens/create_place_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('candidate visibility switch is on by default', (tester) async {
    var value = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidateVisibilitySwitch(
            value: value,
            onChanged: (next) => value = next,
          ),
        ),
      ),
    );

    expect(find.text('Chia sẻ với bạn bè'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
  });
}
