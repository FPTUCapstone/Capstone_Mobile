import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// One UC-32 trip. Every button is driven by a flag the backend sent
/// (`actions`, `review`); nothing is derived on the device.
class TripHistoryCard extends StatelessWidget {
  const TripHistoryCard({
    required this.record,
    required this.onViewEticket,
    required this.onWriteReview,
    required this.onViewReview,
    required this.onViewRefund,
    required this.onViewDetails,
    super.key,
  });

  final TripRecord record;
  final ValueChanged<TripRecord> onViewEticket;
  final ValueChanged<BookingTripRecord> onWriteReview;
  final ValueChanged<BookingTripRecord> onViewReview;
  final ValueChanged<TripRecord> onViewRefund;
  final ValueChanged<TripRecord> onViewDetails;

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    final statusType = switch (record.tab) {
      TripStatus.upcoming => StatusBadgeType.info,
      TripStatus.completed => StatusBadgeType.success,
      TripStatus.cancelled => StatusBadgeType.error,
    };
    final statusLabel = switch (record.tab) {
      TripStatus.upcoming => TripHistoryStringsEn.statusConfirmed,
      TripStatus.completed => TripHistoryStringsEn.statusCompleted,
      TripStatus.cancelled => TripHistoryStringsEn.statusCancelled,
    };
    final typeLabel = switch (record) {
      BookingTripRecord() => TripHistoryStringsEn.filterTour,
      ItineraryTripRecord() => TripHistoryStringsEn.filterItinerary,
    };

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (record is BookingTripRecord)
                  Text(
                    record.bookingCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                StatusBadge(label: typeLabel, type: StatusBadgeType.neutral),
                StatusBadge(label: statusLabel, type: statusType),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              record.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoBox(record: record),
            const SizedBox(height: AppSpacing.sm),
            _Actions(
              record: record,
              onViewEticket: onViewEticket,
              onWriteReview: onWriteReview,
              onViewReview: onViewReview,
              onViewRefund: onViewRefund,
              onViewDetails: onViewDetails,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.record});

  final TripRecord record;

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _InfoLine(
            icon: Icons.calendar_today_outlined,
            label: TripHistoryStringsEn.labelDepartureDate,
            value: TripFormatters.formatVietnamDate(record.departureAtUtc),
          ),
          const SizedBox(height: AppSpacing.xxs),
          switch (record) {
            BookingTripRecord() => Column(
              children: [
                _InfoLine(
                  icon: Icons.people_outline,
                  label: TripHistoryStringsEn.labelParticipants,
                  value: TripHistoryStringsEn.formatParticipants(
                    record.participantCount,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '${TripHistoryStringsEn.labelTotalAmount}:',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    Flexible(
                      child: Text(
                        TripFormatters.formatVnd(record.totalAmount),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ItineraryTripRecord() => Column(
              children: [
                _InfoLine(
                  icon: Icons.place_outlined,
                  label: TripHistoryStringsEn.stopsSectionTitle,
                  value: TripHistoryStringsEn.formatStopCount(record.stopCount),
                ),
                if (record.visitedCount != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  _InfoLine(
                    icon: Icons.check_circle_outline,
                    label: TripHistoryStringsEn.stopVisited,
                    value: TripHistoryStringsEn.formatVisitedOf(
                      record.visitedCount!,
                      record.stopCount,
                    ),
                  ),
                ],
              ],
            ),
          },
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.record,
    required this.onViewEticket,
    required this.onWriteReview,
    required this.onViewReview,
    required this.onViewRefund,
    required this.onViewDetails,
  });

  final TripRecord record;
  final ValueChanged<TripRecord> onViewEticket;
  final ValueChanged<BookingTripRecord> onWriteReview;
  final ValueChanged<BookingTripRecord> onViewReview;
  final ValueChanged<TripRecord> onViewRefund;
  final ValueChanged<TripRecord> onViewDetails;

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    final actions = record.actions;
    const compact = VisualDensity.compact;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        OutlinedButton.icon(
          onPressed: () => onViewDetails(record),
          icon: const Icon(Icons.info_outline, size: 16),
          label: const Text(TripHistoryStringsEn.actionViewDetails),
          style: OutlinedButton.styleFrom(visualDensity: compact),
        ),
        if (actions.canViewETicket && actions.ticketId != null)
          OutlinedButton.icon(
            onPressed: () => onViewEticket(record),
            icon: const Icon(Icons.qr_code, size: 16),
            label: const Text(TripHistoryStringsEn.actionViewEticket),
            style: OutlinedButton.styleFrom(visualDensity: compact),
          ),
        if (record is BookingTripRecord && actions.canReview)
          FilledButton.icon(
            onPressed: () => onWriteReview(record),
            icon: const Icon(Icons.rate_review_outlined, size: 16),
            label: const Text(TripHistoryStringsEn.actionWriteReview),
            style: FilledButton.styleFrom(visualDensity: compact),
          ),
        if (record is BookingTripRecord && record.review.exists)
          OutlinedButton.icon(
            onPressed: () => onViewReview(record),
            icon: const Icon(Icons.reviews_outlined, size: 16),
            label: const Text(TripHistoryStringsEn.actionViewReview),
            style: OutlinedButton.styleFrom(visualDensity: compact),
          ),
        if (actions.canViewRefund)
          FilledButton.tonalIcon(
            onPressed: () => onViewRefund(record),
            icon: const Icon(Icons.currency_exchange, size: 16),
            label: const Text(TripHistoryStringsEn.actionViewRefundStatus),
            style: FilledButton.styleFrom(visualDensity: compact),
          ),
      ],
    );
  }
}
