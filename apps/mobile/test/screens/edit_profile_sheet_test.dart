import 'package:fidee_mobile/screens/edit_profile_sheet.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSheet({
    required Future<AuthResult> Function({
      required String firstName,
      required String lastName,
      required String preferredUsername,
    }) onSave,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EditProfileSheet(
          firstName: 'Nguyen',
          lastName: 'Minh',
          preferredUsername: 'minh',
          onSave: onSave,
          onSaved: () {},
        ),
      ),
    );
  }

  testWidgets('shows save failures inside the edit profile sheet', (tester) async {
    await tester.pumpWidget(
      buildSheet(
        onSave: ({
          required firstName,
          required lastName,
          required preferredUsername,
        }) async {
          return const AuthResult(
            success: false,
            errorMessage: 'Server rejected profile update',
          );
        },
      ),
    );

    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(EditProfileSheet),
        matching: find.text('Server rejected profile update'),
      ),
      findsOneWidget,
    );
  });
}
