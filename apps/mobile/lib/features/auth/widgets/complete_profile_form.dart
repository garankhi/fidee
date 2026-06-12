import 'package:flutter/material.dart';

import '../login_design.dart';
import 'auth_text_field.dart';

typedef CompleteProfileSubmit =
    Future<void> Function(String firstName, String lastName, String username);

class CompleteProfileForm extends StatefulWidget {
  final String? initialFirstName;
  final String? initialLastName;
  final String? initialUsername;
  final bool isSubmitting;
  final String? errorMessage;
  final bool showTitle;
  final CompleteProfileSubmit onSubmit;

  const CompleteProfileForm({
    super.key,
    required this.initialFirstName,
    required this.initialLastName,
    required this.initialUsername,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onSubmit,
    this.showTitle = true,
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
        if (widget.showTitle) ...[
          Text(
            'Hoan tat ho so',
            textAlign: TextAlign.center,
            style: LoginTextStyles.title().copyWith(fontSize: 28),
          ),
          const SizedBox(height: 12),
        ],
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
