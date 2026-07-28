import 'package:fidey_mobile/models/pro_access.dart';
import 'package:fidey_mobile/screens/pro_plan_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('billing actions run only after RevenueCat identity is ready', () async {
    final events = <String>[];

    final result = await runIdentityReadyBillingAction<int>(
      ensureIdentity: () async {
        events.add('identity');
        return true;
      },
      action: () async {
        events.add('action');
        return 42;
      },
    );

    expect(result, 42);
    expect(events, ['identity', 'action']);

    events.clear();
    final skipped = await runIdentityReadyBillingAction<int>(
      ensureIdentity: () async {
        events.add('identity');
        return false;
      },
      action: () async {
        events.add('action');
        return 42;
      },
    );

    expect(skipped, isNull);
    expect(events, ['identity']);
  });

  testWidgets(
    'plan picker shows Vietnamese billing period labels without savings copy',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProPlanPickerPreview(
              monthlyPrice: '49.000đ/tháng',
              yearlyPrice: '399.000đ/năm',
            ),
          ),
        ),
      );

      expect(find.text('Hằng tháng'), findsOneWidget);
      expect(find.text('Hằng năm'), findsOneWidget);
      expect(find.text('Monthly'), findsNothing);
      expect(find.text('Yearly'), findsNothing);
      expect(find.text('49.000đ/tháng'), findsOneWidget);
      expect(find.text('399.000đ/năm'), findsOneWidget);
      expect(find.textContaining('tiết kiệm'), findsNothing);
    },
  );

  testWidgets('plan picker stays busy during backend activation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProPlanPickerPreview(
            monthlyPrice: '49.000đ/tháng',
            yearlyPrice: '399.000đ/năm',
            syncStatus: BillingSyncStatus.reconciling,
          ),
        ),
      ),
    );

    expect(find.text('Đang kích hoạt Pro…'), findsOneWidget);
  });

  testWidgets('startup reconciliation failure does not claim payment', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProPlanPickerPreview(
            monthlyPrice: '49.000đ/tháng',
            yearlyPrice: '399.000đ/năm',
            syncStatus: BillingSyncStatus.failed,
          ),
        ),
      ),
    );

    expect(find.text('Đã thanh toán, chưa kích hoạt được Pro'), findsNothing);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('post-purchase activation failure blocks another purchase', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProPlanPickerPreview(
            monthlyPrice: '49.000đ/tháng',
            yearlyPrice: '399.000đ/năm',
            syncStatus: BillingSyncStatus.idle,
            activationStatus: BillingActivationStatus.failed,
          ),
        ),
      ),
    );

    expect(find.text('Đã thanh toán, chưa kích hoạt được Pro'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tiếp tục'),
    );
    expect(continueButton.onPressed, isNull);
  });
}
