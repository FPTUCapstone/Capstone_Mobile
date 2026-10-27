import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';
import 'package:trip_mate_mobile/features/operator_bookings/utils/operator_booking_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

/// The backend summary for the applied filters, shown as returned (never recomputed on the device).
class OperatorBookingsSummaryStrip extends StatelessWidget {
  const OperatorBookingsSummaryStrip({required this.summary, super.key});

  final OperatorBookingsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Tile(
                label: OperatorBookingsStringsEn.summaryBookings,
                value: '${summary.totalBookings}',
                hint: OperatorBookingsStringsEn.summaryBookingsHint,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _Tile(
                label: OperatorBookingsStringsEn.summaryParticipants,
                value: '${summary.totalParticipants}',
                hint: OperatorBookingsStringsEn.summaryParticipantsHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: _Tile(
            label: OperatorBookingsStringsEn.summaryRevenue,
            value: OperatorBookingFormatters.formatVnd(
              summary.totalConfirmedAmount,
            ),
            hint: OperatorBookingsStringsEn.summaryRevenueHint,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            hint,
            style: textTheme.labelSmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
