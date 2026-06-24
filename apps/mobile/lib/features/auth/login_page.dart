import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import 'auth_providers.dart';
import 'login_design.dart';
import 'screens/register_step2_otp_page.dart';
import 'widgets/login_form.dart';
import 'widgets/login_header.dart';
import 'widgets/login_panel.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _usernameController.text.trim();
    final pwd = _passwordController.text;
    final controller = ref.read(authControllerProvider.notifier);

    if (input.isEmpty || pwd.isEmpty) {
      controller.setError('Vui lòng nhập email và mật khẩu');
      return;
    }

    final result = await controller.signIn(input, pwd);
    if (!mounted || !result.success) return;

    final authState = ref.read(authControllerProvider).valueOrNull;
    if (authState?.authState == AuthState.otpSent) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const RegisterStep2OtpPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: LoginColors.red,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = LoginMetrics.fromSize(constraints.biggest);

          return Stack(
            children: [
              Container(color: LoginColors.red),
              LoginHeader(metrics: metrics),
              Positioned(
                top: metrics.panelTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: const LoginPanel(),
              ),
              Positioned(
                top: metrics.formTop,
                left: metrics.formHorizontalPadding,
                right: metrics.formHorizontalPadding,
                bottom: 0,
                child: LoginForm(
                  usernameController: _usernameController,
                  passwordController: _passwordController,
                  isSubmitting: authState?.isSubmitting ?? false,
                  errorMessage: authState?.errorMessage,
                  isPasswordObscured: _isPasswordObscured,
                  onTogglePasswordVisibility: () {
                    setState(() {
                      _isPasswordObscured = !_isPasswordObscured;
                    });
                  },
                  onSubmit: _submit,
                  onGoogleSignIn: () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithGoogle(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
