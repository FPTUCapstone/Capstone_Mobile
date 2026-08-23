import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    super.key,
  });

  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String label;
  final bool obscureText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }
}
