import 'package:fidee_mobile/screens/ai_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildScreen({String? initialMessage}) {
    return MaterialApp(home: AiChatScreen(initialMessage: initialMessage));
  }

  testWidgets('uses Vietnamese Fidee AI copy', (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('Fidee AI'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsOneWidget);
    expect(find.textContaining('Chào bạn, mình là Fidee'), findsOneWidget);
    expect(find.text('Gợi ý 3 quán gần tôi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Chỉ món không cay'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chỉ món không cay'), findsOneWidget);
    expect(find.text('Lãng mạn và yên tĩnh hơn'), findsOneWidget);
    expect(find.text('Hôm nay bạn muốn vibe thế nào?'), findsOneWidget);
    expect(find.textContaining('Mavi'), findsNothing);
    expect(find.textContaining('Online'), findsNothing);
  });

  testWidgets(
    'sending a message shows Vietnamese acknowledgement and clears input',
    (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.enterText(
        find.byType(TextField),
        'Tìm quán bún chả yên tĩnh',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Tìm quán bún chả yên tĩnh'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tìm quán bún chả yên tĩnh'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Fidee đã nhận vibe của bạn'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Fidee đã nhận vibe của bạn'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    },
  );

  testWidgets('initial message starts the chat automatically', (tester) async {
    await tester.pumpWidget(
      buildScreen(initialMessage: 'Tìm cafe yên tĩnh gần tôi'),
    );

    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Tìm cafe yên tĩnh gần tôi'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tìm cafe yên tĩnh gần tôi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Fidee đã nhận vibe của bạn'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Fidee đã nhận vibe của bạn'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });
}
