import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class TripHistoryCard extends StatelessWidget {
  const TripHistoryCard({
    required this.item,
    required this.onViewEticket,
    required this.onWriteReview,
    required this.onEditReview,
    required this.onViewReview,
    required this.onViewRefundStatus,
    required this.onViewDetails,
    super.key,
  });

  final TripHistoryItem item;
  final ValueChanged<TripHistoryItem> onViewEticket;
  final ValueChanged<TripHistoryItem> onWriteReview;
  final ValueChanged<TripHistoryItem> onEditReview;
  final ValueChanged<TripHistoryItem> onViewReview;
  final ValueChanged<TripHistoryItem> onViewRefundStatus;
  final ValueChanged<TripHistoryItem> onViewDetails;

  @override
  Widget build(BuildContext context) {
    final statusType = switch (item.status) {
      TripStatus.upcoming => StatusBadgeType.info,
      TripStatus.completed => StatusBadgeType.success,
      TripStatus.cancelled => StatusBadgeType.error,
    };

    final statusLabel = switch (item.status) {
      TripStatus.upcoming => TripHistoryStringsEn.statusConfirmed,
      TripStatus.completed => TripHistoryStringsEn.statusCompleted,
      TripStatus.cancelled => TripHistoryStringsEn.statusCancelled,
    };

    final typeLabel = switch (item.type) {
      TripType.tour => TripHistoryStringsEn.filterTour,
      TripType.commercialService =>
        TripHistoryStringsEn.filterCommercialService,
      TripType.itinerary => TripHistoryStringsEn.filterItinerary,
    };

    final formattedDate = TripFormatters.formatVietnamDate(item.departureDate);
    final formattedAmount = TripFormatters.formatVnd(item.totalAmount);
    final participantsText = TripHistoryStringsEn.formatParticipants(
      item.participantsCount,
    );

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
                Text(
                  item.bookingCode,
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

            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Info Grid: Departure Date, Participants, Total Amount
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        '${TripHistoryStringsEn.labelDepartureDate}: ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        '${TripHistoryStringsEn.labelParticipants}: ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          participantsText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${TripHistoryStringsEn.labelTotalAmount}:',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          formattedAmount,
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
            ),
            const SizedBox(height: AppSpacing.sm),

            // Contextual Action Buttons
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                // [View Details] is always available
                OutlinedButton.icon(
                  onPressed: () => onViewDetails(item),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text(TripHistoryStringsEn.actionViewDetails),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),

                // [View E-ticket] for valid bookings
                if (item.hasEticket)
                  OutlinedButton.icon(
                    onPressed: () => onViewEticket(item),
                    icon: const Icon(Icons.qr_code, size: 16),
                    label: const Text(TripHistoryStringsEn.actionViewEticket),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),

                // [Write Review] for completed unreviewed bookings (BR-91, BR-92)
                if (item.canWriteReview)
                  FilledButton.icon(
                    onPressed: () => onWriteReview(item),
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: const Text(TripHistoryStringsEn.actionWriteReview),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),

                // [Edit Review] for completed bookings with review < 7 days (BR-95)
                if (item.canEditReview())
                  FilledButton.tonalIcon(
                    onPressed: () => onEditReview(item),
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text(TripHistoryStringsEn.actionEditReview),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),

                // [View Review] for completed bookings with review > 7 days (read-only)
                if (item.isReadOnlyReview())
                  OutlinedButton.icon(
                    onPressed: () => onViewReview(item),
                    icon: const Icon(Icons.reviews_outlined, size: 16),
                    label: const Text(TripHistoryStringsEn.actionViewReview),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),

                // [View Refund Status] for cancelled bookings (Alternative Flow)
                if (item.canViewRefundStatus)
                  FilledButton.tonalIcon(
                    onPressed: () => onViewRefundStatus(item),
                    icon: const Icon(Icons.currency_exchange, size: 16),
                    label: const Text(
                      TripHistoryStringsEn.actionViewRefundStatus,
                    ),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
