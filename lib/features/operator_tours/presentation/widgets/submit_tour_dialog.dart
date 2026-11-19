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
    title: const Text('Submit for review?'),
    content: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          const Text(
            'Your current changes will be saved first. The tour becomes Pending and read-only while Staff reviews it. It will not appear in public discovery or accept bookings until Staff approval and publication.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Submission note (optional)',
              helperText: 'Add any context for Staff.',
              helperMaxLines: 2,
              errorMaxLines: 3,
            ),
            validator: (value) =>
                (normalizeSubmissionNote(value)?.length ?? 0) > 4000
                ? 'Shorten the submission note to 4,000 characters.'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (note: normalizeSubmissionNote(_note.text)));
          }
        },
        child: const Text('Submit'),
      ),
    ],
  );
}
