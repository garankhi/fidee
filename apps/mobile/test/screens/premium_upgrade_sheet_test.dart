import 'package:fidey_mobile/screens/premium_upgrade_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('premium benefits include gallery images and videos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PremiumUpgradeSheet())),
    );

    expect(find.text('Ảnh & video từ thư viện'), findsOneWidget);
  });
}
