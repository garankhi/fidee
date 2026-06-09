import 'package:fidee_mobile/screens/send_image_preview_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('place tag is a transparent glass surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SendImagePlaceTagPill(label: 'Chọn địa điểm', onTap: () {}),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('send-image-place-tag-pill')),
      findsOneWidget,
    );
    expect(find.text('Chọn địa điểm'), findsOneWidget);

    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('send-image-place-tag-pill')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, const Color(0x26FFFFFF));
  });
}
