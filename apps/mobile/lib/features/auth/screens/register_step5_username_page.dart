import 'package:flutter/material.dart';
import '../../../screens/home_screen.dart';
import '../login_design.dart';
import '../widgets/auth_wizard_layout.dart';

class RegisterStep5UsernamePage extends StatefulWidget {
  const RegisterStep5UsernamePage({super.key});

  @override
  State<RegisterStep5UsernamePage> createState() => _RegisterStep5State();
}

class _RegisterStep5State extends State<RegisterStep5UsernamePage> {
  final _usernameCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_usernameCtrl.text.trim().isEmpty) return;
    
    // TODO: Update backend with full profile (name, gender, dob, username)
    // For now, jump to Home
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthWizardLayout(
      title: 'Tên đăng nhập của bạn',
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          TextField(
            controller: _usernameCtrl,
            textAlign: TextAlign.center,
            cursorColor: LoginColors.red,
            style: LoginTextStyles.title().copyWith(fontSize: 32, fontWeight: FontWeight.w400, color: LoginColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'username',
              hintStyle: LoginTextStyles.title().copyWith(fontSize: 32, fontWeight: FontWeight.w400, color: LoginColors.border),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tạo tên đăng nhập duy nhất.\nĐây là tên hiển thị của bạn với mọi người.',
            textAlign: TextAlign.center,
            style: LoginTextStyles.fieldText().copyWith(fontStyle: FontStyle.italic, height: 1.5),
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

