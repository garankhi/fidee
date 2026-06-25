import 'package:fidey_mobile/screens/home_ai_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSearchBar({
    required ValueChanged<String> onSubmitted,
    VoidCallback? onOpenChat,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: HomeAiSearchBar(
            onSubmitted: onSubmitted,
            onOpenChat: onOpenChat,
          ),
        ),
      ),
    );
  }

  testWidgets('shows animated Vietnamese hint prompts', (tester) async {
    await tester.pumpWidget(buildSearchBar(onSubmitted: (_) {}));

    expect(find.text('Bạn muốn ăn gì hôm nay nào?'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Thời tiết khá là mát mẻ để ăn chè đó'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Phân vân không biết lựa thì cứ hỏi Fidey'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('submits trimmed query when user presses enter', (tester) async {
    String? submitted;

    await tester.pumpWidget(
      buildSearchBar(onSubmitted: (value) => submitted = value),
    );

    await tester.tap(find.byKey(const ValueKey('home-ai-search-field')));
    await tester.enterText(
      find.byKey(const ValueKey('home-ai-search-field')),
      '  tìm cafe yên tĩnh  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(submitted, 'tìm cafe yên tĩnh');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('home-ai-search-field')))
          .controller
          ?.text,
      isEmpty,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('does not submit empty query', (tester) async {
    var submitCount = 0;

    await tester.pumpWidget(buildSearchBar(onSubmitted: (_) => submitCount++));

    await tester.enterText(
      find.byKey(const ValueKey('home-ai-search-field')),
      '   ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(submitCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opens AI chat when sparkle button is tapped', (tester) async {
    var openCount = 0;

    await tester.pumpWidget(
      buildSearchBar(onSubmitted: (_) {}, onOpenChat: () => openCount++),
    );

    await tester.tap(find.byKey(const ValueKey('home-ai-chat-button')));
    await tester.pump();

    expect(openCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
