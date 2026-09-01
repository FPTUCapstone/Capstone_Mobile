import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    required this.controller,
    required this.label,
    this.helperText,
    this.textInputAction,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String? helperText;
  final String label;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  var _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      helperText: widget.helperText,
      label: widget.label,
      obscureText: _obscured,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      suffix: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        tooltip: _obscured ? 'Show password' : 'Hide password',
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off,
        ),
      ),
    );
  }
}
