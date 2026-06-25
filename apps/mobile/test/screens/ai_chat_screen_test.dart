import 'package:fidey_mobile/screens/ai_chat_screen.dart';
import 'package:fidey_mobile/services/ai_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildScreen({
    String? initialMessage,
    List<List<AiContextPlace>>? capturedContexts,
  }) {
    return MaterialApp(
      home: AiChatScreen(
        initialMessage: initialMessage,
        search: (prompt, history, contextPlaces) async {
          capturedContexts?.add(contextPlaces);
          return AiSearchResult(
            answer:
                'Fidey đã tìm qua /search cho "$prompt". Đây là vài gợi ý hợp vibe.',
            results: const [
              AiPlaceResult(
                id: 'place-1',
                name: 'Quán Trà Sữa Test',
                category: 'cafe',
                address: '123 Nguyễn Huệ',
                description: 'Không gian rộng, hợp đi nhóm.',
                similarityScore: 0.82,
                tags: ['Cà phê', 'Wifi'],
              ),
            ],
          );
        },
      ),
    );
  }

  testWidgets('uses Vietnamese Fidey AI copy', (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('Fidey AI'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsOneWidget);
    expect(find.textContaining('Chào bạn, mình là Fidey'), findsOneWidget);
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
        find.textContaining('Fidey đã tìm qua /search'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Fidey đã tìm qua /search'), findsOneWidget);
      expect(find.text('Quán Trà Sữa Test'), findsOneWidget);
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
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Tìm cafe yên tĩnh gần tôi'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tìm cafe yên tĩnh gần tôi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Fidey đã tìm qua /search'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Fidey đã tìm qua /search'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('sends previous place cards as context for follow-up questions', (
    tester,
  ) async {
    final capturedContexts = <List<AiContextPlace>>[];
    await tester.pumpWidget(buildScreen(capturedContexts: capturedContexts));

    await tester.enterText(find.byType(TextField), 'Tìm quán cafe gần đây');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'quán đó mấy giờ đóng cửa');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    expect(capturedContexts.length, 2);
    expect(capturedContexts.first, isEmpty);
    expect(capturedContexts.last.single.id, 'place-1');
    expect(capturedContexts.last.single.name, 'Quán Trà Sữa Test');
  });
}
