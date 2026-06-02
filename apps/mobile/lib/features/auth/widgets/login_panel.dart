import 'package:flutter/material.dart';

import '../login_design.dart';

class LoginPanel extends StatelessWidget {
  const LoginPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: LoginRadii.panel),
      ),
    );
  }
}

class DividerText extends StatelessWidget {
  final String text;

  const DividerText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: LoginColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: LoginTextStyles.divider()),
        ),
        const Expanded(child: Divider(color: LoginColors.divider)),
      ],
    );
  }
}
