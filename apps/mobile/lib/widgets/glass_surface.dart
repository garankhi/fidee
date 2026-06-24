import 'dart:ui';

import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final Color tint;
  final Color highContrastTint;
  final Color borderColor;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius = 24,
    this.blurSigma = 16,
    this.tint = const Color(0x26FFFFFF),
    this.highContrastTint = const Color(0xCC111111),
    this.borderColor = const Color(0x40FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highContrast ? highContrastTint : tint,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
