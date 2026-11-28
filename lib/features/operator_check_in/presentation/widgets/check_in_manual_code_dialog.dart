import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class CheckInManualCodeDialog extends StatefulWidget {
  const CheckInManualCodeDialog({required this.onSubmit, super.key});

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
  State<CheckInManualCodeDialog> createState() =>
      _CheckInManualCodeDialogState();
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
            'Điểm danh thủ công',
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
              'Nhập mã đơn đặt tour (ví dụ: BK-20261030-001) hoặc mã vé (TK-0000000001):',
              style: TextStyle(fontSize: 13, color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Mã đơn hoặc mã vé',
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập mã đơn đặt tour hoặc mã vé';
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
          child: const Text('Hủy'),
        ),
        AppButton(label: 'Điểm danh', onPressed: _submit, minimumHeight: 40),
      ],
    );
  }
}
