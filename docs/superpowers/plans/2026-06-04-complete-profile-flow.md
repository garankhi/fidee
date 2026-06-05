# Complete Profile Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route authenticated users with missing profile data into a dedicated profile completion flow instead of sending them back into register step 3.

**Architecture:** Keep `SplashScreen` as the startup gate and keep `main.dart` as the auth router. Add profile fields to `AuthUiState`, pass those fields into a dedicated `CompleteProfilePage`, and make `AuthState.incompleteProfile` render that page. Split the UI into a pure `CompleteProfileForm` for stable widget tests and a Riverpod page wrapper that calls `AuthController.completeProfile`.

**Tech Stack:** Flutter, Riverpod, riverpod_annotation generated providers, Cognito-backed `AuthService`, existing `AuthWizardLayout`, Flutter widget tests.

---

## File Structure

- Modify `apps/mobile/lib/features/auth/auth_providers.dart`: expose current profile fields in `AuthUiState` so the completion page can prefill known values.
- Create `apps/mobile/lib/features/auth/widgets/complete_profile_form.dart`: pure stateful form with validation, prefilled controllers, inline loading, and no provider dependency.
- Create `apps/mobile/lib/features/auth/screens/complete_profile_page.dart`: provider-aware page that passes profile state into the form and submits through `AuthController.completeProfile`.
- Modify `apps/mobile/lib/main.dart`: route `AuthState.incompleteProfile` to `CompleteProfilePage` instead of `RegisterStep3NamePage`.
- Create `apps/mobile/test/features/auth/auth_ui_state_test.dart`: verifies `AuthUiState.fromService` carries profile values.
- Create `apps/mobile/test/features/auth/complete_profile_form_test.dart`: verifies completion UX, prefilled values, validation, and submit payload without touching async providers.

## Behavioral Requirements

- A restored or signed-in session with `AuthState.incompleteProfile` must show a page titled `Hoan tat ho so`, not `Ten cua ban`.
- The completion form must prefill `firstName`, `lastName`, and `preferredUsername` when available from `AuthUiState`.
- The completion form must require `firstName`, `lastName`, and `username`, matching `services/api/src/handlers/update-profile.ts`.
- `gender` and `dob` remain part of the new registration wizard only because the current API does not persist them.
- After successful submit, `AuthController.completeProfile` sets auth state to `authenticated`; `main.dart` then routes through the existing location gate logic.
- The page may show inline button loading and inline error text, but it must not use a fullscreen spinner or do async initialization before first render.

---

### Task 1: Expose Profile Fields In AuthUiState

**Files:**
- Modify: `apps/mobile/lib/features/auth/auth_providers.dart`
- Test: `apps/mobile/test/features/auth/auth_ui_state_test.dart`

- [ ] **Step 1: Write the failing unit test**

Create `apps/mobile/test/features/auth/auth_ui_state_test.dart`:

```dart
import 'package:fidee_mobile/features/auth/auth_providers.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthUiState', () {
    test('fromService exposes profile fields for profile completion', () async {
      final service = AuthService(isTestMode: true);
      await service.initialize();
      await service.completeProfile('Minh', 'Nguyen', 'minh.nguyen');

      final state = AuthUiState.fromService(service);

      expect(state.firstName, 'Minh');
      expect(state.lastName, 'Nguyen');
      expect(state.preferredUsername, 'minh.nguyen');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run from `apps/mobile`:

```powershell
flutter test test/features/auth/auth_ui_state_test.dart
```

Expected: FAIL with compile errors that `firstName`, `lastName`, and `preferredUsername` are not defined on `AuthUiState`.

- [ ] **Step 3: Add profile fields to AuthUiState**

Modify `apps/mobile/lib/features/auth/auth_providers.dart`.

Add these fields to `AuthUiState`:

```dart
  final String? firstName;
  final String? lastName;
  final String? preferredUsername;
```

Update the constructor:

```dart
  const AuthUiState({
    required this.authState,
    this.tier = UserTier.free,
    this.destination,
    this.resendCooldownRemaining = 0,
    this.isSubmitting = false,
    this.isVerifying = false,
    this.errorMessage,
    this.firstName,
    this.lastName,
    this.preferredUsername,
  });
```

Update `fromService`:

```dart
    return AuthUiState(
      authState: service.state,
      tier: service.tier,
      destination: service.destination,
      resendCooldownRemaining: service.resendCooldownRemaining,
      isSubmitting: isSubmitting,
      isVerifying: isVerifying,
      errorMessage: errorMessage,
      firstName: service.firstName,
      lastName: service.lastName,
      preferredUsername: service.preferredUsername,
    );
```

Update `copyWith` parameters:

```dart
    String? firstName,
    String? lastName,
    String? preferredUsername,
```

Update the `AuthUiState` returned by `copyWith`:

```dart
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      preferredUsername: preferredUsername ?? this.preferredUsername,
```

- [ ] **Step 4: Run the focused test to verify it passes**

Run from `apps/mobile`:

```powershell
flutter test test/features/auth/auth_ui_state_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```powershell
git add apps/mobile/lib/features/auth/auth_providers.dart apps/mobile/test/features/auth/auth_ui_state_test.dart
git commit -m "feat(mobile): expose auth profile fields"
```

---

### Task 2: Build And Test The Pure Complete Profile Form

**Files:**
- Create: `apps/mobile/lib/features/auth/widgets/complete_profile_form.dart`
- Test: `apps/mobile/test/features/auth/complete_profile_form_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Create `apps/mobile/test/features/auth/complete_profile_form_test.dart`:

```dart
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
    Future<void> Function(String firstName, String lastName, String username)? onSubmit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CompleteProfileForm(
          initialFirstName: firstName,
          initialLastName: lastName,
          initialUsername: username,
          isSubmitting: isSubmitting,
          errorMessage: errorMessage,
          onSubmit: onSubmit ?? (_, __, ___) async {},
        ),
      ),
    );
  }

  group('CompleteProfileForm', () {
    testWidgets('shows completion copy and prefilled profile values', (tester) async {
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
          onSubmit: (_, __, ___) async {
            submitted = true;
          },
        ),
      );

      await tester.tap(find.text('Hoan tat'));
      await tester.pump();

      expect(find.text('Vui long nhap day du ho, ten va username'), findsOneWidget);
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

      await tester.tap(find.text('Hoan tat'));
      await tester.pump();

      expect(submitted, ['Minh', 'Nguyen', 'Minh.Nguyen']);
    });

    testWidgets('shows provider error text inline', (tester) async {
      await tester.pumpWidget(buildForm(errorMessage: 'Username da duoc su dung'));

      expect(find.text('Username da duoc su dung'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the widget test to verify it fails**

Run from `apps/mobile`:

```powershell
flutter test test/features/auth/complete_profile_form_test.dart
```

Expected: FAIL because `complete_profile_form.dart` does not exist.

- [ ] **Step 3: Implement CompleteProfileForm**

Create `apps/mobile/lib/features/auth/widgets/complete_profile_form.dart`:

```dart
import 'package:flutter/material.dart';

import '../login_design.dart';
import 'auth_text_field.dart';

typedef CompleteProfileSubmit = Future<void> Function(
  String firstName,
  String lastName,
  String username,
);

class CompleteProfileForm extends StatefulWidget {
  final String? initialFirstName;
  final String? initialLastName;
  final String? initialUsername;
  final bool isSubmitting;
  final String? errorMessage;
  final CompleteProfileSubmit onSubmit;

  const CompleteProfileForm({
    super.key,
    required this.initialFirstName,
    required this.initialLastName,
    required this.initialUsername,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onSubmit,
  });

  @override
  State<CompleteProfileForm> createState() => _CompleteProfileFormState();
}

class _CompleteProfileFormState extends State<CompleteProfileForm> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _usernameCtrl;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.initialFirstName ?? '');
    _lastNameCtrl = TextEditingController(text: widget.initialLastName ?? '');
    _usernameCtrl = TextEditingController(text: widget.initialUsername ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || username.isEmpty) {
      setState(() {
        _localError = 'Vui long nhap day du ho, ten va username';
      });
      return;
    }

    setState(() {
      _localError = null;
    });

    await widget.onSubmit(firstName, lastName, username);
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _localError ?? widget.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'Hoan tat ho so',
          textAlign: TextAlign.center,
          style: LoginTextStyles.title().copyWith(fontSize: 28),
        ),
        const SizedBox(height: 12),
        Text(
          'Them thong tin con thieu de bat dau dung Fidee.',
          textAlign: TextAlign.center,
          style: LoginTextStyles.fieldText(),
        ),
        const SizedBox(height: 28),
        AuthTextField(
          controller: _firstNameCtrl,
          label: 'Ho',
          hintText: 'Nguyen',
        ),
        const SizedBox(height: 18),
        AuthTextField(
          controller: _lastNameCtrl,
          label: 'Ten',
          hintText: 'Minh',
        ),
        const SizedBox(height: 18),
        AuthTextField(
          controller: _usernameCtrl,
          label: 'Username',
          hintText: 'minh.nguyen',
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 14),
          Text(
            errorMessage,
            style: LoginTextStyles.error(),
            textAlign: TextAlign.center,
          ),
        ],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LoginColors.red,
                elevation: 0,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LoginRadii.button),
                ),
              ),
              onPressed: widget.isSubmitting ? null : _submit,
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Hoan tat', style: LoginTextStyles.button()),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the widget test to verify it passes**

Run from `apps/mobile`:

```powershell
flutter test test/features/auth/complete_profile_form_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 2**

```powershell
git add apps/mobile/lib/features/auth/widgets/complete_profile_form.dart apps/mobile/test/features/auth/complete_profile_form_test.dart
git commit -m "feat(mobile): add complete profile form"
```

---

### Task 3: Add The Provider-Aware Completion Page

**Files:**
- Create: `apps/mobile/lib/features/auth/screens/complete_profile_page.dart`
- Modify: `apps/mobile/test/features/auth/complete_profile_form_test.dart`

- [ ] **Step 1: Add a regression assertion for page-level copy**

The pure form already carries the visible UX. Keep this assertion in `apps/mobile/test/features/auth/complete_profile_form_test.dart`:

```dart
      expect(find.text('Hoan tat ho so'), findsOneWidget);
      expect(find.text('Ten cua ban'), findsNothing);
```

Run from `apps/mobile`:

```powershell
flutter test test/features/auth/complete_profile_form_test.dart
```

Expected: PASS before creating the provider wrapper.

- [ ] **Step 2: Implement CompleteProfilePage**

Create `apps/mobile/lib/features/auth/screens/complete_profile_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_providers.dart';
import '../widgets/auth_wizard_layout.dart';
import '../widgets/complete_profile_form.dart';

class CompleteProfilePage extends ConsumerWidget {
  final String? initialFirstName;
  final String? initialLastName;
  final String? initialUsername;

  const CompleteProfilePage({
    super.key,
    required this.initialFirstName,
    required this.initialLastName,
    required this.initialUsername,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final isSubmitting = authState?.isSubmitting ?? false;
    final errorMessage = authState?.errorMessage;

    return AuthWizardLayout(
      title: 'Hoan tat ho so',
      onBack: () => ref.read(authControllerProvider.notifier).signOut(),
      child: CompleteProfileForm(
        initialFirstName: initialFirstName,
        initialLastName: initialLastName,
        initialUsername: initialUsername,
        isSubmitting: isSubmitting,
        errorMessage: errorMessage,
        onSubmit: (firstName, lastName, username) async {
          await ref
              .read(authControllerProvider.notifier)
              .completeProfile(firstName, lastName, username);
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Run static analysis for the new page**

Run from `apps/mobile`:

```powershell
flutter analyze
```

Expected: PASS or only pre-existing unrelated warnings. If there are pre-existing warnings, capture them before changing implementation.

- [ ] **Step 4: Run focused tests**

Run from `apps/mobile`:

```powershell
flutter test test/features/auth/auth_ui_state_test.dart test/features/auth/complete_profile_form_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 3**

```powershell
git add apps/mobile/lib/features/auth/screens/complete_profile_page.dart apps/mobile/test/features/auth/complete_profile_form_test.dart
git commit -m "feat(mobile): add complete profile page"
```

---

### Task 4: Route Incomplete Profiles To The Completion Page

**Files:**
- Modify: `apps/mobile/lib/main.dart`

- [ ] **Step 1: Update main.dart imports**

Modify `apps/mobile/lib/main.dart`.

Replace:

```dart
import 'features/auth/screens/register_step3_name_page.dart';
```

With:

```dart
import 'features/auth/screens/complete_profile_page.dart';
```

- [ ] **Step 2: Update the incomplete profile branch**

Replace the `AuthState.incompleteProfile` branch in `apps/mobile/lib/main.dart` with:

```dart
    } else if (state.authState == AuthState.incompleteProfile) {
      // Authenticated user is missing required profile fields.
      // Keep this outside the register wizard so users do not feel sent back to signup.
      return CompleteProfilePage(
        initialFirstName: state.firstName,
        initialLastName: state.lastName,
        initialUsername: state.preferredUsername,
      );
    } else {
```

- [ ] **Step 3: Run static analysis**

Run from `apps/mobile`:

```powershell
flutter analyze
```

Expected: PASS with no unused import for `RegisterStep3NamePage`.

- [ ] **Step 4: Run focused tests**

Run from `apps/mobile`:

```powershell
flutter test test/features/auth/auth_ui_state_test.dart test/features/auth/complete_profile_form_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 4**

```powershell
git add apps/mobile/lib/main.dart
git commit -m "feat(mobile): route incomplete profiles to completion"
```

---

### Task 5: Verify Full Mobile Scope

**Files:**
- Verify only: `apps/mobile`

- [ ] **Step 1: Run all Flutter tests**

Run from `apps/mobile`:

```powershell
flutter test
```

Expected: PASS for service tests and new auth tests.

- [ ] **Step 2: Run static analysis**

Run from `apps/mobile`:

```powershell
flutter analyze
```

Expected: PASS.

- [ ] **Step 3: Generated code check when provider annotations changed**

Run this only if implementation changes a `@riverpod` or `@Riverpod` declaration:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Expected: generated files remain consistent. If this command changes generated files, include those files in the final commit.

- [ ] **Step 4: Manual UX check**

Run the app and use a session that resolves to `AuthState.incompleteProfile`.

Expected sequence:

```text
SplashScreen red gate
-> CompleteProfilePage titled Hoan tat ho so
-> user fills missing first name, last name, username
-> submit success
-> existing LocationGateScreen or HomeScreen route
```

Confirm there is no route from cold-start incomplete profile to `RegisterStep3NamePage`.

- [ ] **Step 5: Commit verification-only cleanup if needed**

If formatting, generated files, or test adjustments changed files:

```powershell
git add apps/mobile
git commit -m "test(mobile): verify complete profile flow"
```

If no files changed, do not create an empty commit.

---

## Self-Review

- Spec coverage: The plan covers the approved approach: dedicated completion page, no redirect to register step 3, prefilled profile fields, existing `/profile` submit path, and AGENTS.md startup-gate rules.
- Placeholder scan: No deferred requirements are left for implementers.
- Type consistency: `firstName`, `lastName`, and `preferredUsername` are consistently named across `AuthService`, `AuthUiState`, `CompleteProfilePage`, and `CompleteProfileForm`.
- Scope check: The plan does not add API persistence for `gender` or `dob` because the existing `/profile` API does not accept those fields.
