import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.enabled = true,
    this.helperText,
    this.initialValue,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.onTap,
    this.prefixIcon,
    this.readOnly = false,
    this.suffix,
    this.textInputAction,
    this.validator,
    super.key,
  });

  final TextEditingController? controller;
  final bool enabled;
  final String? helperText;
  final String? initialValue;
  final TextInputType? keyboardType;
  final String label;
  final int maxLines;
  final bool obscureText;
  final VoidCallback? onTap;
  final Widget? prefixIcon;
  final bool readOnly;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      onTap: onTap,
      readOnly: readOnly,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        helperText: helperText,
        labelText: label,
        prefixIcon: prefixIcon,
        suffixIcon: suffix,
      ),
    );
  }
}
