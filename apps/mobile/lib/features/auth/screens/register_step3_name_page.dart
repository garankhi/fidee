import 'package:flutter/material.dart';
import '../login_design.dart';
import '../widgets/auth_wizard_layout.dart';
import 'register_step4_info_page.dart';

class RegisterStep3NamePage extends StatefulWidget {
  const RegisterStep3NamePage({super.key});

  @override
  State<RegisterStep3NamePage> createState() => _RegisterStep3State();
}

class _RegisterStep3State extends State<RegisterStep3NamePage> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RegisterStep4InfoPage(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthWizardLayout(
      title: 'Tên của bạn',
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          TextField(
            controller: _firstNameCtrl,
            textAlign: TextAlign.center,
            cursorColor: LoginColors.red,
            style: LoginTextStyles.title().copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: LoginColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Họ',
              hintStyle: LoginTextStyles.title().copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                color: LoginColors.border,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _lastNameCtrl,
            textAlign: TextAlign.center,
            cursorColor: LoginColors.red,
            style: LoginTextStyles.title().copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: LoginColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Tên',
              hintStyle: LoginTextStyles.title().copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                color: LoginColors.border,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submit,
                style: TextButton.styleFrom(foregroundColor: LoginColors.red),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tiếp tục', style: LoginTextStyles.button()),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
