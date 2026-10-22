import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_cubit.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_state.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

final class BookingRefundProgressPage extends StatefulWidget {
  const BookingRefundProgressPage({required this.bookingId, super.key});
  final String bookingId;

  @override
  State<BookingRefundProgressPage> createState() =>
      _BookingRefundProgressPageState();
}

final class _BookingRefundProgressPageState
    extends State<BookingRefundProgressPage> {
  @override
  void initState() {
    super.initState();
    context.read<BookingRefundProgressCubit>().load(widget.bookingId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Refund progress')),
    body: BlocBuilder<BookingRefundProgressCubit, BookingRefundProgressState>(
      builder: (context, state) => switch (state.status) {
        BookingRefundProgressStatus.initial ||
        BookingRefundProgressStatus.loading => const Center(
          child: LoadingIndicator(),
        ),
        BookingRefundProgressStatus.failure => _Failure(
          message: state.failure?.message ?? 'Could not load refund progress.',
          onRetry: () =>
              context.read<BookingRefundProgressCubit>().load(widget.bookingId),
        ),
        BookingRefundProgressStatus.success when state.progress != null =>
          _Progress(progress: state.progress!),
        _ => const _Failure(message: 'Could not load refund progress.'),
      },
    ),
  );
}

final class _Progress extends StatelessWidget {
  const _Progress({required this.progress});
  final BookingRefundProgress progress;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(progress.status);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: presentation.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BOOKING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          progress.bookingCode,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: presentation.label,
                    type: presentation.badgeType,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                presentation.description,
                style: const TextStyle(color: AppColors.ink, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _DetailCard(
          rows: [
            _Row(
              'Refund amount',
              TripFormatters.formatVnd(progress.refundAmount),
            ),
            _Row('Requested', _formatDate(progress.requestedAtUtc)),
            _Row('Completed', _formatDate(progress.processedAtUtc)),
            if (progress.nextAttemptAtUtc != null)
              _Row('Next attempt', _formatDate(progress.nextAttemptAtUtc)),
            if (progress.gatewayReference != null)
              _Row('Reference', progress.gatewayReference!),
            if (progress.attemptCount > 0)
              _Row('Attempts', '${progress.attemptCount}'),
          ],
        ),
        if (progress.status == BookingRefundStatus.failed) ...[
          const SizedBox(height: AppSpacing.md),
          const AppAlert(
            type: AppAlertType.info,
            message:
                'No action is needed from you. Our support team will contact you if more information is required.',
          ),
        ],
      ],
    );
  }
}

final class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.rows});
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    rows[index].label,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    rows[index].value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            if (index != rows.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    ),
  );
}

final class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}

final class _Failure extends StatelessWidget {
  const _Failure({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAlert(message: message, type: AppAlertType.error),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    ),
  );
}

({
  String label,
  String description,
  StatusBadgeType badgeType,
  Color background,
})
_presentation(BookingRefundStatus status) => switch (status) {
  BookingRefundStatus.processed => (
    label: 'Refund completed',
    description:
        'The refund has been completed through the original payment channel.',
    badgeType: StatusBadgeType.success,
    background: const Color(0xFFEAF8F2),
  ),
  BookingRefundStatus.manualReview => (
    label: 'Under manual review',
    description: 'Our team is verifying this refund with the payment provider.',
    badgeType: StatusBadgeType.warning,
    background: const Color(0xFFFFF8E8),
  ),
  BookingRefundStatus.failed => (
    label: 'Needs attention',
    description:
        'We could not complete the refund automatically. Support will follow up.',
    badgeType: StatusBadgeType.error,
    background: const Color(0xFFFFF1F2),
  ),
  BookingRefundStatus.rejected => (
    label: 'Refund not approved',
    description: 'This refund was not approved under the applicable policy.',
    badgeType: StatusBadgeType.neutral,
    background: const Color(0xFFF1F5F9),
  ),
  BookingRefundStatus.retryPending => (
    label: 'Retry scheduled',
    description: 'We will retry the refund shortly.',
    badgeType: StatusBadgeType.info,
    background: const Color(0xFFEFF6FF),
  ),
  BookingRefundStatus.processing => (
    label: 'Processing refund',
    description: 'The payment provider is processing your refund.',
    badgeType: StatusBadgeType.info,
    background: const Color(0xFFEFF6FF),
  ),
  BookingRefundStatus.pending => (
    label: 'Refund requested',
    description: 'Your refund request has been received.',
    badgeType: StatusBadgeType.info,
    background: const Color(0xFFEFF6FF),
  ),
};

String _formatDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
