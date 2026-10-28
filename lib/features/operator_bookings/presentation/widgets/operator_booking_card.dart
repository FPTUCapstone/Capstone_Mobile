import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';
import 'package:trip_mate_mobile/features/operator_bookings/utils/operator_booking_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// One booking of the list (#84). It opens the detail (#85); nothing on it changes a booking.
class OperatorBookingCard extends StatelessWidget {
  const OperatorBookingCard({
    required this.booking,
    required this.onTap,
    super.key,
  });

  final OperatorBookingListItem booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      hint: OperatorBookingsStringsEn.cardOpenDetails,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  booking.bookingCode,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                StatusBadge(
                  label: OperatorBookingFormatters.statusLabel(booking.status),
                  type: OperatorBookingFormatters.statusBadge(booking.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              booking.tour.title,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            _InfoLine(
              label: OperatorBookingsStringsEn.cardDeparture,
              value: OperatorBookingFormatters.date(
                booking.schedule.startAtUtc,
              ),
            ),
            _InfoLine(
              label: OperatorBookingsStringsEn.cardBooker,
              value: booking.booker.fullName,
            ),
            _InfoLine(
              label: OperatorBookingsStringsEn.cardParticipants,
              value: '${booking.quantity}',
            ),
            _InfoLine(
              label: OperatorBookingsStringsEn.cardTotal,
              value: OperatorBookingFormatters.formatVnd(booking.totalAmount),
              emphasised: true,
            ),
            const SizedBox(height: AppSpacing.xs),
            StatusBadge(
              label: OperatorBookingFormatters.checkInLabel(
                booking.checkInStatus,
              ),
              type: OperatorBookingFormatters.checkInBadge(
                booking.checkInStatus,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: style?.copyWith(color: AppColors.muted),
            ),
            TextSpan(
              text: value,
              style: style?.copyWith(
                color: AppColors.ink,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
