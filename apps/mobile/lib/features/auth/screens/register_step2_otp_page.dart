import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_providers.dart';
import '../login_design.dart';
import '../widgets/auth_wizard_layout.dart';
import 'register_step3_name_page.dart';

class RegisterStep2OtpPage extends ConsumerStatefulWidget {
  const RegisterStep2OtpPage({super.key});

  @override
  ConsumerState<RegisterStep2OtpPage> createState() => _RegisterStep2State();
}

class _RegisterStep2State extends ConsumerState<RegisterStep2OtpPage> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _submit() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) return;

    final controller = ref.read(authControllerProvider.notifier);
    final result = await controller.verifyOtp(code);

    if (!mounted || !result.success) return;

    // After OTP is verified, Cognito session is valid, but profile is empty.
    // AuthController state changes to incompleteProfile (or authenticated if testing).
    // We explicitly navigate to Step 3 here.
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RegisterStep3NamePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final errorMessage = authState?.errorMessage;
    final isVerifying = authState?.isVerifying ?? false;

    return AuthWizardLayout(
      title: 'Kiểm tra mã xác thực OTP đã được gửi tới email của bạn',
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 45,
                height: 65,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  cursorColor: LoginColors.red,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ), // Fix white text on white bg
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineBorder(color: LoginColors.textMuted),
                    focusedBorder: OutlineBorder(color: LoginColors.red),
                    errorBorder: OutlineBorder(color: LoginColors.red),
                  ),
                  onChanged: (value) => _onChanged(value, index),
                ),
              );
            }),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: LoginTextStyles.error(),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Chưa nhận được mã? ', style: LoginTextStyles.fieldText()),
              TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).resendOtp(),
                style: TextButton.styleFrom(
                  foregroundColor: LoginColors.red,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Gửi lại', style: LoginTextStyles.action()),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isVerifying ? null : _submit,
                style: TextButton.styleFrom(foregroundColor: LoginColors.red),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tiếp tục', style: LoginTextStyles.button()),
                    const SizedBox(width: 8),
                    if (isVerifying)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: LoginColors.red,
                        ),
                      )
                    else
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

class OutlineBorder extends OutlineInputBorder {
  OutlineBorder({required Color color})
    : super(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: color, width: 1.5),
      );
}
