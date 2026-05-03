import 'package:flutter/material.dart';

import '../theme/colors.dart';

class NovaInputField extends StatelessWidget {
  const NovaInputField({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 15,
        height: 1.45,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: colors.textSecondary,
          fontSize: 14.5,
        ),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: colors.textSecondary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
    );
  }
}
