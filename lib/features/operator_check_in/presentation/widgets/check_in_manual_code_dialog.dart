import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class CheckInManualCodeDialog extends StatefulWidget {
  const CheckInManualCodeDialog({
    required this.onSubmit,
    super.key,
  });

  final ValueChanged<String> onSubmit;

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => CheckInManualCodeDialog(
        onSubmit: (code) => Navigator.of(dialogContext).pop(code),
      ),
    );
  }

  @override
  State<CheckInManualCodeDialog> createState() => _CheckInManualCodeDialogState();
}

class _CheckInManualCodeDialogState extends State<CheckInManualCodeDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_note_rounded, color: AppColors.primary),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Manual Check-in',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the traveler\'s booking code (e.g. BK-20261030-001) or ticket code (TK-0000000001):',
              style: TextStyle(fontSize: 13, color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Booking or Ticket Code',
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a booking or ticket code';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Check In',
          onPressed: _submit,
          minimumHeight: 40,
        ),
      ],
    );
  }
}
