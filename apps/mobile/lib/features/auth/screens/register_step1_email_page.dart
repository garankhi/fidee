import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth_providers.dart';
import '../login_design.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_wizard_layout.dart';
import '../widgets/login_panel.dart';
import 'register_step2_otp_page.dart';

class RegisterStep1EmailPage extends ConsumerStatefulWidget {
  const RegisterStep1EmailPage({super.key});

  @override
  ConsumerState<RegisterStep1EmailPage> createState() => _RegisterStep1State();
}

class _RegisterStep1State extends ConsumerState<RegisterStep1EmailPage> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _obscurePwd = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    final confirm = _confirmPwdCtrl.text;
    final controller = ref.read(authControllerProvider.notifier);

    if (email.isEmpty || pwd.isEmpty || confirm.isEmpty) {
      controller.setError('Vui lòng nhập đầy đủ thông tin');
      return;
    }
    if (pwd != confirm) {
      controller.setError('Mật khẩu nhập lại không khớp');
      return;
    }

    final result = await controller.signUp(email, pwd);
    if (!mounted || !result.success) return;

    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RegisterStep2OtpPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final isSubmitting = authState?.isSubmitting ?? false;
    final errorMessage = authState?.errorMessage;

    return AuthWizardLayout(
      title: 'Bắt đầu ngay!',
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _emailCtrl,
            label: 'Email',
            hintText: 'example@gmail.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: _pwdCtrl,
            label: 'Mật khẩu',
            hintText: '••••••••••••••••',
            obscureText: _obscurePwd,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePwd ? Icons.visibility : Icons.visibility_off,
                color: LoginColors.iconMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
            ),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: _confirmPwdCtrl,
            label: 'Nhập lại mật khẩu',
            hintText: '••••••••••••••••',
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                color: LoginColors.iconMuted,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: LoginTextStyles.error(),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
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
              onPressed: isSubmitting ? null : _submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Đăng kí', style: LoginTextStyles.button()),
            ),
          ),
          const SizedBox(height: 32),
          const DividerText(text: 'hoặc'),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LoginColors.googleButton,
                elevation: 0,
                foregroundColor: const Color(0xFF5F5F5F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LoginRadii.googleButton),
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () => ref
                        .read(authControllerProvider.notifier)
                        .signInWithGoogle(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    LoginAssets.googleIcon,
                    width: 21,
                    height: 21,
                  ),
                  const SizedBox(width: 18),
                  Text(
                    'Tiếp tục với Google',
                    style: LoginTextStyles.googleButton(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Đã có tài khoản?',
                style: LoginTextStyles.fieldText().copyWith(fontSize: 13),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: LoginColors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Đăng nhập', style: LoginTextStyles.action()),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            '© 2026 Bản quyền thuộc về Fidey',
            textAlign: TextAlign.center,
            style: LoginTextStyles.footer(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
