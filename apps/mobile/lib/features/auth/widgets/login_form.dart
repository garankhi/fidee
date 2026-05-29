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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome!',
            textAlign: TextAlign.center,
            style: LoginTextStyles.title(),
          ),
          const SizedBox(height: 42),
          AuthTextField(
            controller: usernameController,
            label: 'Email or Phone Number',
            hintText: 'example@gmail.com',
            keyboardType: TextInputType.emailAddress,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(errorMessage!, style: LoginTextStyles.error()),
          ],
          const SizedBox(height: 20),
          AuthTextField(
            controller: passwordController,
            label: 'Password',
            hintText: '••••••••••••••••',
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
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: LoginColors.red,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {},
              child: Text('Forgot Password?', style: LoginTextStyles.action()),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 39,
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
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Login', style: LoginTextStyles.button()),
            ),
          ),
          const SizedBox(height: 34),
          const DividerText(text: 'or'),
          const SizedBox(height: 49),
          Center(
            child: SizedBox(
              width: 286,
              height: 47,
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
                        'Continue with Google',
                        style: LoginTextStyles.googleButton(),
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
                  MaterialPageRoute<void>(builder: (_) => const RegisterStep1EmailPage()),
                );
              },
              child: Text('Create an account', style: LoginTextStyles.action()),
            ),
          ),
          const SizedBox(height: 52),
          Text(
            '© 2026 MapVibe. All rights reserved.',
            textAlign: TextAlign.center,
            style: LoginTextStyles.footer(),
          ),
        ],
      ),
    );
  }
}

