import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.enabled = true,
    this.errorText,
    this.helperText,
    this.initialValue,
    this.inputFormatters,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.onChanged,
    this.onTap,
    this.prefixIcon,
    this.readOnly = false,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.validator,
    super.key,
  });

  final TextEditingController? controller;
  final bool enabled;
  final String? errorText;
  final String? helperText;
  final String? initialValue;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final String label;
  final int maxLines;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Widget? prefixIcon;
  final bool readOnly;
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      initialValue: controller == null ? initialValue : null,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        errorText: errorText,
        helperText: helperText,
        labelText: label,
        prefixIcon: prefixIcon,
        suffixIcon: suffix,
      ),
    );
  }
}
