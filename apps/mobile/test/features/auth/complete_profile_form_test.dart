import 'package:fidey_mobile/features/auth/widgets/complete_profile_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder fieldWithValue(String value) {
    return find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == value,
      description: 'TextField with value $value',
    );
  }

  Widget buildForm({
    String? firstName = 'Minh',
    String? lastName,
    String? username = 'minh',
    bool isSubmitting = false,
    String? errorMessage,
    Future<void> Function(String firstName, String lastName, String username)?
    onSubmit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CompleteProfileForm(
          initialFirstName: firstName,
          initialLastName: lastName,
          initialUsername: username,
          isSubmitting: isSubmitting,
          errorMessage: errorMessage,
          onSubmit: onSubmit ?? (_, _, _) async {},
        ),
      ),
    );
  }

  group('CompleteProfileForm', () {
    testWidgets('shows completion copy and prefilled profile values', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());

      expect(find.text('Hoàn tất hồ sơ'), findsOneWidget);
      expect(find.text('Tên của bạn'), findsNothing);
      expect(fieldWithValue('Minh'), findsOneWidget);
      expect(fieldWithValue('minh'), findsOneWidget);
    });

    testWidgets('requires all profile fields before submit', (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        buildForm(
          onSubmit: (_, _, _) async {
            submitted = true;
          },
        ),
      );

      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(
        find.text('Vui lòng nhập đầy đủ họ, tên và tên đăng nhập'),
        findsOneWidget,
      );
      expect(submitted, isFalse);
    });

    testWidgets('rejects email as first name before submit', (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        buildForm(
          firstName: 'nguyenminh110505@gmail.com',
          lastName: 'Minh Nguyen',
          username: 'ngxtm122',
          onSubmit: (_, _, _) async {
            submitted = true;
          },
        ),
      );

      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Họ không được là email'), findsOneWidget);
      expect(submitted, isFalse);
    });

    testWidgets('submits trimmed profile values', (tester) async {
      late List<String> submitted;
      await tester.pumpWidget(
        buildForm(
          firstName: ' Minh ',
          lastName: ' Nguyen ',
          username: ' Minh.Nguyen ',
          onSubmit: (firstName, lastName, username) async {
            submitted = [firstName, lastName, username];
          },
        ),
      );

      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(submitted, ['Minh', 'Nguyen', 'Minh.Nguyen']);
    });

    testWidgets('shows provider error text inline', (tester) async {
      await tester.pumpWidget(
        buildForm(errorMessage: 'Username da duoc su dung'),
      );

      expect(find.text('Username da duoc su dung'), findsOneWidget);
    });
  });
}
