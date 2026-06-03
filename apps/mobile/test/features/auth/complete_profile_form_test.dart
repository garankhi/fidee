import 'package:fidee_mobile/features/auth/widgets/complete_profile_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

      expect(find.text('Hoan tat ho so'), findsOneWidget);
      expect(find.text('Ten cua ban'), findsNothing);
      expect(find.displayingText('Minh'), findsOneWidget);
      expect(find.displayingText('minh'), findsOneWidget);
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

      await tester.ensureVisible(find.text('Hoan tat'));
      await tester.tap(find.text('Hoan tat'));
      await tester.pump();

      expect(
        find.text('Vui long nhap day du ho, ten va username'),
        findsOneWidget,
      );
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

      await tester.ensureVisible(find.text('Hoan tat'));
      await tester.tap(find.text('Hoan tat'));
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
