import 'package:flutter/material.dart';

import '../login_design.dart';

class LoginHeader extends StatelessWidget {
  final LoginMetrics metrics;

  const LoginHeader({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: metrics.panelTop,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                LoginAssets.logo,
                width: 180,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
