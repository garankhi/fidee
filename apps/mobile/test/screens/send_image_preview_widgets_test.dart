import 'package:fidee_mobile/screens/send_image_preview_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('place tag uses gray background with white content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SendImagePlaceTagPill(label: 'Marukame Udon', onTap: () {}),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('send-image-place-tag-pill')),
      findsOneWidget,
    );
    expect(find.text('Marukame Udon'), findsOneWidget);

    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('send-image-place-tag-pill')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xCC4A4A4A));

    final icon = tester.widget<Icon>(find.byIcon(Icons.location_on_rounded));
    expect(icon.color, Colors.white);

    final text = tester.widget<Text>(find.text('Marukame Udon'));
    expect(text.style?.color, Colors.white);
  });
}
