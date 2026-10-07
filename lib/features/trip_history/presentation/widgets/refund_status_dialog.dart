import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_refund_info.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class RefundStatusDialog extends StatelessWidget {
  const RefundStatusDialog({
    required this.refundInfo,
    required this.bookingCode,
    super.key,
  });

  final TripRefundInfo refundInfo;
  final String bookingCode;

  @override
  Widget build(BuildContext context) {
    final badgeType = switch (refundInfo.status) {
      RefundStatus.refunded => StatusBadgeType.success,
      RefundStatus.processing => StatusBadgeType.warning,
      RefundStatus.nonRefundable => StatusBadgeType.neutral,
    };

    final statusLabel = switch (refundInfo.status) {
      RefundStatus.refunded => TripHistoryStringsEn.refundStateRefunded,
      RefundStatus.processing => TripHistoryStringsEn.refundStateProcessing,
      RefundStatus.nonRefundable =>
        TripHistoryStringsEn.refundStateNonRefundable,
    };

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          const Expanded(child: Text(TripHistoryStringsEn.refundDialogTitle)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${TripHistoryStringsEn.labelBookingCode}: $bookingCode',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    TripHistoryStringsEn.refundState,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                StatusBadge(label: statusLabel, type: badgeType),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    TripHistoryStringsEn.refundedAmount,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  TripFormatters.formatVnd(refundInfo.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    TripHistoryStringsEn.refundChannel,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    refundInfo.channel,
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: AppColors.ink),
                  ),
                ),
              ],
            ),
            if (refundInfo.note != null && refundInfo.note!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                TripHistoryStringsEn.refundNote,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.xxs),
                ),
                child: Text(
                  refundInfo.note!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(TripHistoryStringsEn.actionClose),
        ),
      ],
    );
  }
}
