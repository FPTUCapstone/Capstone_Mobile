import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_failure.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/presentation/cubit/booking_cancellation_cubit.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/presentation/cubit/booking_cancellation_state.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/resources/booking_cancellation_en.dart';

/// UC-41 cancellation sheet opened from the e-ticket page. Returns `true` to the opener
/// when the booking was cancelled, so the caller can reload its own state.
class BookingCancelSheet extends StatefulWidget {
  const BookingCancelSheet({super.key});

  static Future<bool?> show(BuildContext context, {required int bookingId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) =>
            serviceLocator<BookingCancellationCubit>(param1: bookingId)..load(),
        child: const BookingCancelSheet(),
      ),
    );
  }

  @override
  State<BookingCancelSheet> createState() => _BookingCancelSheetState();
}

class _BookingCancelSheetState extends State<BookingCancelSheet> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _failureMessage(BookingCancellationFailureKind kind) => switch (kind) {
    BookingCancellationFailureKind.signIn => BookingCancellationStrings.signIn,
    BookingCancellationFailureKind.notFound =>
      BookingCancellationStrings.notFound,
    BookingCancellationFailureKind.forbidden =>
      BookingCancellationStrings.forbidden,
    BookingCancellationFailureKind.invalidState =>
      BookingCancellationStrings.invalidState,
    BookingCancellationFailureKind.reasonRequired =>
      BookingCancellationStrings.reasonRequired,
    BookingCancellationFailureKind.confirmationRequired =>
      BookingCancellationStrings.reasonRequired,
    BookingCancellationFailureKind.paymentNotRefundable =>
      BookingCancellationStrings.paymentNotRefundable,
    BookingCancellationFailureKind.windowClosed =>
      BookingCancellationStrings.windowClosed,
    BookingCancellationFailureKind.idempotencyMismatch =>
      BookingCancellationStrings.idempotencyMismatch,
    BookingCancellationFailureKind.system => BookingCancellationStrings.system,
  };

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingCancellationCubit, BookingCancellationState>(
      listenWhen: (previous, current) =>
          current.phase == BookingCancellationPhase.success,
      listener: (context, state) => Navigator.of(context).pop(true),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          MediaQuery.of(context).padding.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              BookingCancellationStrings.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            BlocBuilder<BookingCancellationCubit, BookingCancellationState>(
              builder: (context, state) => switch (state.phase) {
                BookingCancellationPhase.loading => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: AppSpacing.sm),
                        Text(BookingCancellationStrings.loading),
                      ],
                    ),
                  ),
                ),
                _ => _Body(
                  state: state,
                  reasonController: _reasonController,
                  failureMessage: _failureMessage,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.reasonController,
    required this.failureMessage,
  });

  final BookingCancellationState state;
  final TextEditingController reasonController;
  final String Function(BookingCancellationFailureKind) failureMessage;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview;
    final cubit = context.read<BookingCancellationCubit>();
    final submitting = state.phase == BookingCancellationPhase.submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview != null) ...[
          Text(
            preview.tourTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            children: [
              Text('${BookingCancellationStrings.refundLabel}: '),
              Text(
                preview.estimatedRefundAmount > 0
                    ? '${preview.estimatedRefundAmount.toStringAsFixed(0)} VND'
                    : BookingCancellationStrings.noRefund,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (preview.estimatedRefundAmount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              BookingCancellationStrings.refundPending,
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ],
          if (!preview.canCancel && preview.blockingReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              preview.blockingReason!,
              style: TextStyle(color: AppColors.error),
            ),
          ],
          if (state.needsConfirmation) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: state.confirmed,
                  onChanged: submitting
                      ? null
                      : (value) => cubit.toggleConfirmed(value ?? false),
                ),
                Expanded(child: Text(BookingCancellationStrings.confirmLabel)),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: reasonController,
            enabled: !submitting,
            decoration: const InputDecoration(
              labelText: BookingCancellationStrings.reasonLabel,
            ),
            maxLines: 2,
          ),
        ],
        if (state.phase == BookingCancellationPhase.failure &&
            state.failure != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            failureMessage(state.failure!),
            style: TextStyle(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(context).maybePop(false),
                child: const Text(BookingCancellationStrings.close),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: state.canSubmit
                    ? () => cubit.submit(
                        reasonDetail: reasonController.text.trim().isEmpty
                            ? null
                            : reasonController.text.trim(),
                      )
                    : null,
                child: Text(
                  BookingCancellationStrings.confirm,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
