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
    })
    onSave,
    Future<UsernameAvailabilityResult> Function(String username)?
    onCheckUsername,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EditProfileSheet(
          firstName: 'Nguyen',
          lastName: 'Minh',
          preferredUsername: 'minh',
          onSave: onSave,
          onCheckUsername:
              onCheckUsername ??
              (_) async => const UsernameAvailabilityResult(
                success: true,
                available: true,
              ),
          onSaved: () {},
        ),
      ),
    );
  }

  testWidgets('shows save failures inside the edit profile sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSheet(
        onSave:
            ({
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

  testWidgets('disables save when username is already taken', (tester) async {
    await tester.pumpWidget(
      buildSheet(
        onSave:
            ({
              required firstName,
              required lastName,
              required preferredUsername,
            }) async {
              return const AuthResult(success: true);
            },
        onCheckUsername: (_) async => const UsernameAvailabilityResult(
          success: true,
          available: false,
          errorMessage: 'Username đã được sử dụng',
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(2), 'taken');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('Username đã được sử dụng'), findsOneWidget);

    final saveButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Lưu'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('enables save when initial username is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSheet(
        onSave:
            ({
              required firstName,
              required lastName,
              required preferredUsername,
            }) async {
              return const AuthResult(success: true);
            },
      ),
    );

    final saveButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Lưu'),
    );
    expect(saveButton.onPressed, isNotNull);
  });
  testWidgets('saves a changed available username', (tester) async {
    String? savedUsername;

    await tester.pumpWidget(
      buildSheet(
        onSave:
            ({
              required firstName,
              required lastName,
              required preferredUsername,
            }) async {
              savedUsername = preferredUsername;
              return const AuthResult(success: true);
            },
        onCheckUsername: (username) async => UsernameAvailabilityResult(
          success: true,
          available: true,
          normalizedUsername: username.trim().toLowerCase(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(2), 'new_name');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('Username có thể sử dụng'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
    await tester.pump();
    await tester.pump();

    expect(savedUsername, 'new_name');
  });
}
