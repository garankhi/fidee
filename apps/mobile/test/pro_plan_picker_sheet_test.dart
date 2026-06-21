import 'package:fidee_mobile/screens/pro_plan_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
