import 'package:flutter/material.dart';

// Since SF-Pro is an Apple system font and cannot be easily bundled due to licensing,
// we fall back to standard sans-serif which is Roboto on Android and SF-Pro on iOS.
// For a pure cross-platform SF-Pro look, one would need to manually download the TTF
// from Apple, place it in assets, and configure pubspec.yaml. 
// For now, we use the default text theme which maps to system defaults (SF Pro on iOS).
TextStyle _baseTextStyle() => const TextStyle(fontFamily: '.SF Pro Text');

class LoginColors {
  static const red = Color(0xFFEF4050);
  static const textPrimary = Colors.black;
  static const textMuted = Color(0xFF767676);
  static const border = Color(0xFFE4E4E4);
  static const divider = Color(0xFFECECEC);
  static const googleButton = Color(0xFFF1F1F1);
  static const iconMuted = Color(0xFFD8D8D8);
  static const footer = Color(0xFF898989);
}

class LoginAssets {
  static const logo = 'assets/images/logo.png';
  static const googleIcon = 'assets/icons/google.svg';
}

class LoginRadii {
  static const panel = Radius.circular(28);
  static const input = 12.0;
  static const button = 10.0;
  static const googleButton = 8.0;
}

class LoginTextStyles {
  static TextStyle title() {
    return _baseTextStyle().copyWith(
      color: LoginColors.textPrimary,
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }

  static TextStyle fieldText() {
    return _baseTextStyle().copyWith(
      color: LoginColors.textMuted,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );
  }

  static TextStyle fieldLabel() {
    return _baseTextStyle().copyWith(
      color: LoginColors.textMuted,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }

  static TextStyle action({Color color = LoginColors.red}) {
    return _baseTextStyle().copyWith(
      color: color,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }

  static TextStyle button() {
    return _baseTextStyle().copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }

  static TextStyle googleButton() {
    return _baseTextStyle().copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );
  }

  static TextStyle divider() {
    return _baseTextStyle().copyWith(
      color: const Color(0xFF7C7C7C),
      fontSize: 12,
      letterSpacing: 0,
    );
  }

  static TextStyle error() {
    return _baseTextStyle().copyWith(
      color: LoginColors.red,
      fontSize: 12,
      letterSpacing: 0,
    );
  }

  static TextStyle footer() {
    return _baseTextStyle().copyWith(
      color: LoginColors.footer,
      fontSize: 10,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
  }
}

class LoginMetrics {
  final double panelTop;
  final double formTop;
  final double logoTop;
  final double backTop;
  final double formHorizontalPadding;

  const LoginMetrics({
    required this.panelTop,
    required this.formTop,
    required this.logoTop,
    required this.backTop,
    required this.formHorizontalPadding,
  });

  factory LoginMetrics.fromSize(Size size) {
    final panelTop = (size.height * 0.30).clamp(180.0, 250.0);
    return LoginMetrics(
      panelTop: panelTop,
      formTop: panelTop + 45,
      logoTop: (panelTop * 0.29).clamp(64.0, 78.0),
      backTop: (panelTop * 0.20).clamp(42.0, 54.0),
      formHorizontalPadding: size.width < 360 ? 18 : 22,
    );
  }
}
