import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/validation/post_trip_complaint_validation.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_cubit.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_state.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/resources/post_trip_complaint_strings.dart';

final class PostTripComplaintPage extends StatefulWidget {
  const PostTripComplaintPage({super.key});

  @override
  State<PostTripComplaintPage> createState() => _PostTripComplaintPageState();
}

final class _PostTripComplaintPageState extends State<PostTripComplaintPage> {
  final _detail = TextEditingController();
  final _amendment = <SelectedEvidence>[];
  String? _pickerError;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(context),
        ),
        title: const Text(
          PostTripComplaintStrings.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: BlocBuilder<PostTripComplaintCubit, PostTripComplaintState>(
        builder: (context, state) {
          final cubit = context.read<PostTripComplaintCubit>();
          if (state.phase == PostTripComplaintPhase.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.phase == PostTripComplaintPhase.failure) {
            return _Failure(message: state.message, onRetry: cubit.load);
          }
          final complaintContext = state.context;
          if (complaintContext == null) {
            return _Failure(
              message: PostTripComplaintStrings.systemError,
              onRetry: cubit.load,
            );
          }
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _Summary(context: complaintContext),
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      state.message!,
                      style: TextStyle(
                        color:
                            (state.message ==
                                    PostTripComplaintStrings.submitted ||
                                state.message ==
                                    PostTripComplaintStrings.evidenceAdded)
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_pickerError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      _pickerError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                if (state.phase == PostTripComplaintPhase.eligible ||
                    state.phase == PostTripComplaintPhase.submitting)
                  _Form(
                    state: state,
                    detail: _detail,
                    onPick: () => _pickInitial(cubit),
                    onSubmit: cubit.submit,
                  )
                else if (complaintContext.complaint != null)
                  _Existing(
                    context: complaintContext,
                    amendment: _amendment,
                    busy: state.isBusy,
                    onRemove: (index) =>
                        setState(() => _amendment.removeAt(index)),
                    onPick: _pickAmendment,
                    onAmend: () async {
                      await cubit.amend(_amendment);
                      if (mounted &&
                          cubit.state.context?.canAmendEvidence == false) {
                        setState(_amendment.clear);
                      }
                    },
                    onDownload: (id) => _download(cubit, id),
                  )
                else
                  _Closed(
                    reason: complaintContext.ineligibilityReason,
                    onBack: () => context.go('/traveler/trips'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickInitial(PostTripComplaintCubit cubit) async {
    final files = await _pick();
    if (files == null || !mounted || cubit.isClosed || cubit.state.isBusy)
      return;
    final current = cubit.state.evidence;
    final accepted = _acceptEvidence(
      files,
      existingCount: current.length,
      existingBytes: current.fold(0, (sum, item) => sum + item.sizeBytes),
    );
    if (accepted.isNotEmpty) {
      cubit.setEvidence([...current, ...accepted]);
    }
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/traveler/trips');
  }

  Future<void> _pickAmendment() async {
    final files = await _pick();
    if (files == null || !mounted) return;
    final cubit = context.read<PostTripComplaintCubit>();
    if (cubit.isClosed || cubit.state.isBusy) return;
    final existing = cubit.state.context?.complaint?.evidence ?? const [];
    final accepted = _acceptEvidence(
      files,
      existingCount: existing.length + _amendment.length,
      existingBytes:
          existing.fold(0, (sum, item) => sum + item.sizeBytes) +
          _amendment.fold(0, (sum, item) => sum + item.sizeBytes),
    );
    if (accepted.isNotEmpty) setState(() => _amendment.addAll(accepted));
  }

  List<SelectedEvidence> _acceptEvidence(
    List<SelectedEvidence> candidates, {
    required int existingCount,
    required int existingBytes,
  }) {
    final accepted = <SelectedEvidence>[];
    PostTripComplaintValidationMessage? issue;
    for (final candidate in candidates) {
      final result = PostTripComplaintValidation.validateEvidence(
        [candidate],
        existingCount: existingCount + accepted.length,
        existingBytes:
            existingBytes +
            accepted.fold(0, (sum, item) => sum + item.sizeBytes),
        requireData: true,
      );
      if (result == null) {
        accepted.add(candidate);
      } else {
        issue ??= result;
      }
    }
    if (mounted) {
      setState(
        () => _pickerError = issue == null ? null : _pickerMessage(issue),
      );
    }
    return accepted;
  }

  String _pickerMessage(PostTripComplaintValidationMessage issue) =>
      switch (issue) {
        PostTripComplaintValidationMessage.unsupportedType =>
          PostTripComplaintStrings.evidenceTypeInvalid,
        PostTripComplaintValidationMessage.fileTooLarge ||
        PostTripComplaintValidationMessage.totalTooLarge =>
          PostTripComplaintStrings.evidenceTooLarge,
        PostTripComplaintValidationMessage.tooManyFiles =>
          PostTripComplaintStrings.tooManyEvidence,
        PostTripComplaintValidationMessage.missingFileData =>
          PostTripComplaintStrings.evidenceDataUnavailable,
        _ => PostTripComplaintStrings.invalidEvidence,
      };

  Future<List<SelectedEvidence>?> _pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return null;
    return result.files
        .map(
          (file) => SelectedEvidence(
            name: file.name,
            sizeBytes: file.size,
            contentType: _contentType(file.extension),
            bytes: file.bytes,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _download(PostTripComplaintCubit cubit, int evidenceId) async {
    final data = await cubit.downloadEvidence(evidenceId);
    if (data == null || !mounted) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.bytes,
              name: data.fileName,
              mimeType: data.contentType,
            ),
          ],
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(PostTripComplaintStrings.downloadUnavailable),
          ),
        );
      }
    }
  }

  static String _contentType(String? extension) =>
      switch (extension?.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };
}

class _Summary extends StatelessWidget {
  const _Summary({required this.context});
  final PostTripComplaintContext context;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            this.context.bookingCode ?? 'Booking',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (this.context.tourTitle != null) Text(this.context.tourTitle!),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Submit by ${DateFormat('dd/MM/yyyy HH:mm').format(this.context.submissionDeadlineUtc.toLocal())}',
          ),
        ],
      ),
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message ?? PostTripComplaintStrings.systemError),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: onRetry,
          child: const Text(PostTripComplaintStrings.retry),
        ),
      ],
    ),
  );
}

class _Closed extends StatelessWidget {
  const _Closed({this.reason, required this.onBack});
  final String? reason;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(switch (reason) {
        'complaint.tour_not_ended' =>
          'You can submit a complaint after the tour has ended.',
        'complaint.booking_status_ineligible' =>
          'Only confirmed or completed bookings are eligible for a post-trip complaint.',
        _ => PostTripComplaintStrings.windowClosed,
      }),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(onPressed: onBack, child: const Text('Back to trips')),
    ],
  );
}

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.detail,
    required this.onPick,
    required this.onSubmit,
  });
  final PostTripComplaintState state;
  final TextEditingController detail;
  final VoidCallback onPick;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) {
    final busy = state.isBusy;
    final cubit = context.read<PostTripComplaintCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<PostTripComplaintReasonCategory>(
          isExpanded: true,
          initialValue: state.category,
          decoration: const InputDecoration(labelText: 'Reason category'),
          items: PostTripComplaintReasonCategory.values
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: busy ? null : cubit.setCategory,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: detail,
          enabled: !busy,
          maxLength: 2000,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Reason details',
            border: OutlineInputBorder(),
          ),
          onChanged: cubit.setDetail,
        ),
        TextButton.icon(
          onPressed: busy ? null : onPick,
          icon: const Icon(Icons.attach_file),
          label: const Text('Choose evidence'),
        ),
        const Text(
          'Optional: up to 5 JPG, PNG, WebP or PDF files. Maximum 10 MB per file and 30 MB total.',
        ),
        ...state.evidence.asMap().entries.map(
          (entry) => ListTile(
            dense: true,
            title: Text(entry.value.name),
            subtitle: Text('${entry.value.sizeBytes} bytes'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove evidence',
              onPressed: busy
                  ? null
                  : () {
                      final copied = [...state.evidence]..removeAt(entry.key);
                      cubit.setEvidence(copied);
                    },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: Text(busy ? 'Submitting...' : PostTripComplaintStrings.submit),
        ),
      ],
    );
  }
}

class _Existing extends StatelessWidget {
  const _Existing({
    required this.context,
    required this.amendment,
    required this.onPick,
    required this.onAmend,
    required this.onDownload,
    required this.busy,
    required this.onRemove,
  });
  final PostTripComplaintContext context;
  final List<SelectedEvidence> amendment;
  final VoidCallback onPick;
  final VoidCallback onAmend;
  final ValueChanged<int> onDownload;
  final bool busy;
  final ValueChanged<int> onRemove;
  @override
  Widget build(BuildContext context) {
    final complaint = this.context.complaint!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complaint details',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Status: ${complaint.status.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')}',
        ),
        Text(
          'Operator response deadline: ${DateFormat('dd/MM/yyyy HH:mm').format(complaint.responseDeadlineUtc.toLocal())}',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(complaint.reasonDetail),
        const SizedBox(height: AppSpacing.sm),
        ...complaint.evidence.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${item.sizeBytes} bytes'),
                TextButton.icon(
                  onPressed: () => onDownload(item.id),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text(PostTripComplaintStrings.download),
                ),
              ],
            ),
          ),
        ),
        if (this.context.canAmendEvidence) ...[
          const Divider(),
          TextButton.icon(
            onPressed: busy ? null : onPick,
            icon: const Icon(Icons.add),
            label: const Text('Choose additional files'),
          ),
          ...amendment.asMap().entries.map(
            (entry) => ListTile(
              title: Text(entry.value.name),
              subtitle: Text('${entry.value.sizeBytes} bytes'),
              trailing: IconButton(
                tooltip: 'Remove evidence',
                icon: const Icon(Icons.close),
                onPressed: busy ? null : () => onRemove(entry.key),
              ),
            ),
          ),
          FilledButton(
            onPressed: busy || amendment.isEmpty ? null : onAmend,
            child: Text(busy ? 'Uploading...' : 'Submit additional evidence'),
          ),
        ],
      ],
    );
  }
}
