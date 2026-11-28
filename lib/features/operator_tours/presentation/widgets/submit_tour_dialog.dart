import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';

/// Confirmation owns its input so dismissing it cannot save or submit the editor.
final class SubmitTourDialog extends StatefulWidget {
  const SubmitTourDialog({required this.title, super.key});
  final String title;

  @override
  State<SubmitTourDialog> createState() => _SubmitTourDialogState();
}

final class _SubmitTourDialogState extends State<SubmitTourDialog> {
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Gửi phê duyệt gói tour?'),
    content: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          const Text(
            'Các thay đổi hiện tại sẽ được lưu trước. Gói tour sẽ chuyển sang trạng thái Chờ duyệt và chỉ được xem trong khi nhân viên xét duyệt. Tour sẽ chưa hiển thị công khai hoặc nhận đặt chỗ cho đến khi được nhân viên phê duyệt và đăng bán.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Ghi chú gửi duyệt (tùy chọn)',
              helperText: 'Thêm thông tin cần lưu ý cho nhân viên xét duyệt.',
              helperMaxLines: 2,
              errorMaxLines: 3,
            ),
            validator: (value) =>
                (normalizeSubmissionNote(value)?.length ?? 0) > 4000
                ? 'Vui lòng rút gọn ghi chú gửi duyệt xuống tối đa 4.000 ký tự.'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (note: normalizeSubmissionNote(_note.text)));
          }
        },
        child: const Text('Gửi duyệt'),
      ),
    ],
  );
}
