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

    return AuthWizardLayout(
      title: 'Hoan tat ho so',
      onBack: () => ref.read(authControllerProvider.notifier).signOut(),
      child: CompleteProfileForm(
        initialFirstName: initialFirstName,
        initialLastName: initialLastName,
        initialUsername: initialUsername,
        isSubmitting: authState?.isSubmitting ?? false,
        errorMessage: authState?.errorMessage,
        showTitle: false,
        onSubmit: (firstName, lastName, username) async {
          await ref
              .read(authControllerProvider.notifier)
              .completeProfile(firstName, lastName, username);
        },
      ),
    );
  }
}
