import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/validation/post_trip_complaint_validation.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_cubit.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_state.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/resources/post_trip_complaint_strings.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

String _formatLocalDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

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
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppCoastalAppBar(
        title: PostTripComplaintStrings.title,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(context),
        ),
      ),
      body: BlocBuilder<PostTripComplaintCubit, PostTripComplaintState>(
        builder: (context, state) {
          final cubit = context.read<PostTripComplaintCubit>();
          if (state.phase == PostTripComplaintPhase.loading) {
            return Center(child: CircularProgressIndicator(color: c.brandTeal));
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
          final isPositiveMessage =
              state.message == PostTripComplaintStrings.submitted ||
              state.message == PostTripComplaintStrings.evidenceAdded;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _Summary(context: complaintContext),
                if (state.message != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppAlert(
                    type: isPositiveMessage
                        ? AppAlertType.success
                        : AppAlertType.error,
                    message: state.message!,
                  ),
                ],
                if (_pickerError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppAlert(type: AppAlertType.error, message: _pickerError!),
                ],
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
    if (files == null || !mounted || cubit.isClosed || cubit.state.isBusy) {
      return;
    }
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
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                size: 18,
                color: c.brandTeal,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  this.context.bookingCode ?? 'Đơn đặt tour',
                  style: TextStyle(
                    fontFamily: AppTypography.displayFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (this.context.tourTitle != null) ...[
            const SizedBox(height: 2),
            Text(
              this.context.tourTitle!,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Hạn gửi: ${_formatLocalDateTime(this.context.submissionDeadlineUtc)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ErrorView(
    message: message ?? PostTripComplaintStrings.systemError,
    retryLabel: PostTripComplaintStrings.retry,
    onRetry: onRetry,
  );
}

class _Closed extends StatelessWidget {
  const _Closed({this.reason, required this.onBack});
  final String? reason;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppAlert(
          type: AppAlertType.info,
          message: switch (reason) {
            'complaint.tour_not_ended' =>
              'Bạn có thể gửi khiếu nại sau khi tour kết thúc.',
            'complaint.booking_status_ineligible' =>
              'Chỉ đơn đặt tour đã xác nhận hoặc đã hoàn thành mới đủ điều kiện gửi khiếu nại sau chuyến đi.',
            _ => PostTripComplaintStrings.windowClosed,
          },
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: onBack,
          child: const Text('Quay lại Chuyến đi'),
        ),
      ],
    ),
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
    final c = context.tmColors;
    final busy = state.isBusy;
    final cubit = context.read<PostTripComplaintCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<PostTripComplaintReasonCategory>(
                isExpanded: true,
                initialValue: state.category,
                decoration: const InputDecoration(labelText: 'Danh mục lý do'),
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
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: detail,
                enabled: !busy,
                maxLength: 2000,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Chi tiết lý do',
                  border: OutlineInputBorder(),
                ),
                onChanged: cubit.setDetail,
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : onPick,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Chọn minh chứng'),
                ),
              ),
              Text(
                'Không bắt buộc: tối đa 5 tệp JPG, PNG, WebP hoặc PDF. Tối đa 10 MB mỗi tệp và tổng cộng 30 MB.',
                style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.4),
              ),
              if (state.evidence.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                ...state.evidence.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.canvas,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.borderSubtle),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.insert_drive_file_outlined,
                            size: 18,
                            color: c.brandTeal,
                          ),
                          title: Text(
                            entry.value.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${entry.value.sizeBytes} byte',
                            style: TextStyle(color: c.textMuted),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Xóa minh chứng',
                            onPressed: busy
                                ? null
                                : () {
                                    final copied = [...state.evidence]
                                      ..removeAt(entry.key);
                                    cubit.setEvidence(copied);
                                  },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: Text(busy ? 'Đang gửi...' : PostTripComplaintStrings.submit),
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
    final c = context.tmColors;
    final complaint = this.context.complaint!;
    return AppSectionCard(
      title: 'Chi tiết khiếu nại',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trạng thái: ${PostTripComplaintStrings.statusLabel(complaint.status)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: c.brandTeal,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hạn phản hồi của đơn vị điều hành: ${_formatLocalDateTime(complaint.responseDeadlineUtc)}',
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: c.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.borderSubtle),
            ),
            child: Text(
              complaint.reasonDetail,
              style: TextStyle(color: c.textPrimary, height: 1.45),
            ),
          ),
          if (complaint.evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...complaint.evidence.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: c.canvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        '${item.sizeBytes} byte',
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                      TextButton.icon(
                        onPressed: () => onDownload(item.id),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text(PostTripComplaintStrings.download),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (this.context.canAmendEvidence) ...[
            Divider(height: 24, color: c.borderSubtle),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : onPick,
                icon: const Icon(Icons.add),
                label: const Text('Chọn thêm tệp'),
              ),
            ),
            ...amendment.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.canvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderSubtle),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      title: Text(entry.value.name),
                      subtitle: Text('${entry.value.sizeBytes} byte'),
                      trailing: IconButton(
                        tooltip: 'Xóa minh chứng',
                        icon: const Icon(Icons.close),
                        onPressed: busy ? null : () => onRemove(entry.key),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: busy || amendment.isEmpty ? null : onAmend,
              child: Text(busy ? 'Đang tải lên...' : 'Gửi minh chứng bổ sung'),
            ),
          ],
        ],
      ),
    );
  }
}
