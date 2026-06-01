import 'package:flutter/material.dart';

import '../login_design.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextAlign textAlign;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: LoginColors.red,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textAlign: textAlign,
      style: const TextStyle(fontFamily: 'SF Pro', color: Colors.black),
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        hintText: hintText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontFamily: 'SF Pro'),
        floatingLabelStyle: LoginTextStyles.fieldLabel(),
        hintStyle: const TextStyle(fontFamily: 'SF Pro'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 26,
          vertical: 17,
        ),
        enabledBorder: _inputBorder(LoginColors.border),
        focusedBorder: _inputBorder(LoginColors.red),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
      ),
    );
  }

  OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(LoginRadii.input),
      borderSide: BorderSide(color: color, width: 1.2),
    );
  }
}
