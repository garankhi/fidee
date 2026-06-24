import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../login_design.dart';
import '../screens/register_step1_email_page.dart';
import 'auth_text_field.dart';
import 'login_panel.dart';

class LoginForm extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isPasswordObscured;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleSignIn;

  const LoginForm({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.isSubmitting,
    this.errorMessage,
    required this.isPasswordObscured,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
    required this.onGoogleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'SF Pro'),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chào mừng bạn quay lại!',
              textAlign: TextAlign.center,
              style: LoginTextStyles.title().copyWith(
                fontFamily: 'SF Pro',
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 66),
            AuthTextField(
              controller: usernameController,
              label: 'Email',
              // hintText: 'example@gmail.com',
              keyboardType: TextInputType.emailAddress,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: LoginTextStyles.error().copyWith(fontFamily: 'SF Pro'),
              ),
            ],
            const SizedBox(height: 30),
            AuthTextField(
              controller: passwordController,
              label: 'Mật khẩu',
              // hintText: '••••••••••••••••',
              obscureText: isPasswordObscured,
              suffixIcon: IconButton(
                icon: Icon(
                  isPasswordObscured ? Icons.visibility : Icons.visibility_off,
                  color: LoginColors.iconMuted,
                  size: 20,
                ),
                onPressed: onTogglePasswordVisibility,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: LoginColors.red,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {},
                child: Text(
                  'Quên mật khẩu?',
                  style: LoginTextStyles.action().copyWith(
                    fontFamily: 'SF Pro',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LoginColors.red,
                  elevation: 0,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LoginRadii.button),
                  ),
                ),
                onPressed: isSubmitting ? null : onSubmit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Đăng nhập',
                        style: LoginTextStyles.button().copyWith(
                          fontFamily: 'SF Pro',
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 34),
            const DividerText(text: 'hoặc'),
            const SizedBox(height: 49),
            Center(
              child: SizedBox(
                width: 300,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LoginColors.googleButton,
                    elevation: 0,
                    foregroundColor: const Color(0xFF5F5F5F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        LoginRadii.googleButton,
                      ),
                    ),
                  ),
                  onPressed: isSubmitting ? null : onGoogleSignIn,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        LoginAssets.googleIcon,
                        width: 21,
                        height: 21,
                      ),
                      const SizedBox(width: 18),
                      Flexible(
                        child: Text(
                          'Tiếp tục với Google',
                          style: LoginTextStyles.googleButton().copyWith(
                            fontFamily: 'SF Pro',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: LoginColors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterStep1EmailPage(),
                    ),
                  );
                },
                child: Text(
                  'Tạo tài khoản mới',
                  style: LoginTextStyles.action().copyWith(
                    fontFamily: 'SF Pro',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 52),
            Text(
              '© 2026 Bản quyền thuộc về FIDEE',
              textAlign: TextAlign.center,
              style: LoginTextStyles.footer().copyWith(fontFamily: 'SF Pro'),
            ),
          ],
        ),
      ),
    );
  }
}
