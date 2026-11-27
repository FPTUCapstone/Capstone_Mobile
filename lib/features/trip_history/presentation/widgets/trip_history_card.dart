import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

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
    this.onViewEmergencyNotice,
    this.hasEmergencyNotice = false,
    super.key,
  });

  final TripRecord record;
  final ValueChanged<TripRecord> onViewEticket;
  final ValueChanged<BookingTripRecord> onWriteReview;
  final ValueChanged<BookingTripRecord> onViewReview;
  final ValueChanged<TripRecord> onViewRefund;
  final ValueChanged<TripRecord> onViewDetails;

  /// UC-70. Null where notices cannot be read, such as demo records.
  final ValueChanged<BookingTripRecord>? onViewEmergencyNotice;

  /// The Backend reports an emergency operation for this booking; a Cancelled
  /// status alone never implies one.
  final bool hasEmergencyNotice;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = isDark ? p.border : const Color(0xFFEDEAE1);
    final record = this.record;

    final statusLabel = switch (record.tab) {
      TripStatus.upcoming => TripHistoryStringsEn.statusConfirmed,
      TripStatus.completed => TripHistoryStringsEn.statusCompleted,
      // Shares the tab with cancelled bookings, but the tour was not cancelled.
      TripStatus.cancelled when record.status == 'Interrupted' =>
        TripHistoryStringsEn.statusStoppedForSafety,
      TripStatus.cancelled => TripHistoryStringsEn.statusCancelled,
    };

    final (statusBg, statusFg) = switch (record.tab) {
      TripStatus.upcoming => (p.softAccent, p.primary),
      TripStatus.completed => (p.softAccent, p.primary),
      TripStatus.cancelled => (
        p.errorBg,
        isDark ? p.error : const Color(0xFF8C1030),
      ),
    };

    final isBooking = record is BookingTripRecord;
    final typeLabel = isBooking
        ? TripHistoryStringsEn.filterTour
        : TripHistoryStringsEn.filterItinerary;
    final typeBg = isBooking
        ? (isDark ? p.warningBg : const Color(0xFFF6EDE8))
        : p.canvas;
    final typeFg = isBooking
        ? (isDark ? p.accent : const Color(0xFF995436))
        : p.secondary;

    final displayTitle = switch (record) {
      BookingTripRecord() => record.title,
      ItineraryTripRecord() => formatTripDisplayTitle(
        title: record.title,
        validFrom: record.departureAtUtc,
      ),
    };

    final formattedDate = TripFormatters.formatVietnamDate(
      record.departureAtUtc,
    );
    final bookingRating =
        record is BookingTripRecord &&
            record.review.exists &&
            record.review.rating != null
        ? record.review.rating
        : null;

    return Card(
      elevation: 0,
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(label: typeLabel, bg: typeBg, fg: typeFg),
                      _Pill(label: statusLabel, bg: statusBg, fg: statusFg),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (bookingRating != null) ...[
                  Text(
                    '★ $bookingRating.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? p.accent : const Color(0xFF995436),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: p.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              displayTitle,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
                height: 1.3,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 6),
            _MetaLine(record: record),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 1, color: hairline),
            ),
            _Actions(
              record: record,
              onViewEticket: onViewEticket,
              onWriteReview: onWriteReview,
              onViewReview: onViewReview,
              onViewRefund: onViewRefund,
              onViewDetails: onViewDetails,
              onViewEmergencyNotice: hasEmergencyNotice
                  ? onViewEmergencyNotice
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.record});

  final TripRecord record;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    final mutedStyle = TextStyle(fontSize: 12.5, color: p.secondary);
    final dot = Text(' · ', style: mutedStyle);

    return switch (record) {
      final BookingTripRecord booking => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text(
            booking.bookingCode,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: p.secondary,
            ),
          ),
          dot,
          Text(
            TripHistoryStringsEn.formatParticipants(booking.participantCount),
            style: mutedStyle,
          ),
          dot,
          Text(
            TripFormatters.formatVnd(booking.totalAmount),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
        ],
      ),
      final ItineraryTripRecord itinerary => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text(
            TripHistoryStringsEn.formatStopCount(itinerary.stopCount),
            style: mutedStyle,
          ),
          if (itinerary.visitedCount != null) ...[
            dot,
            Text(
              TripHistoryStringsEn.formatVisitedOf(
                itinerary.visitedCount!,
                itinerary.stopCount,
              ),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ],
        ],
      ),
    };
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
    required this.onViewEmergencyNotice,
  });

  final TripRecord record;
  final ValueChanged<TripRecord> onViewEticket;
  final ValueChanged<BookingTripRecord> onWriteReview;
  final ValueChanged<BookingTripRecord> onViewReview;
  final ValueChanged<TripRecord> onViewRefund;
  final ValueChanged<TripRecord> onViewDetails;
  final ValueChanged<BookingTripRecord>? onViewEmergencyNotice;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    final record = this.record;
    final openNotice = onViewEmergencyNotice;
    final actions = record.actions;

    final secondaryStyle = OutlinedButton.styleFrom(
      foregroundColor: p.ink,
      backgroundColor: p.surface,
      side: BorderSide(color: p.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(
        fontFamily: AppTypography.uiFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

    final softStyle = OutlinedButton.styleFrom(
      foregroundColor: p.primary,
      backgroundColor: p.canvas,
      side: BorderSide(color: p.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(
        fontFamily: AppTypography.uiFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

    final primaryStyle = FilledButton.styleFrom(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(
        fontFamily: AppTypography.uiFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => onViewDetails(record),
          style: secondaryStyle,
          child: const Text(TripHistoryStringsEn.actionViewDetails),
        ),
        if (actions.canViewETicket && actions.ticketId != null)
          OutlinedButton.icon(
            onPressed: () => onViewEticket(record),
            icon: Icon(Icons.qr_code_2, size: 15, color: p.primary),
            label: const Text(TripHistoryStringsEn.actionViewEticket),
            style: softStyle,
          ),
        if (record is BookingTripRecord && actions.canReview)
          FilledButton(
            onPressed: () => onWriteReview(record),
            style: primaryStyle,
            child: const Text(TripHistoryStringsEn.actionWriteReview),
          ),
        if (record is BookingTripRecord && record.review.exists)
          OutlinedButton(
            onPressed: () => onViewReview(record),
            style: softStyle,
            child: const Text(TripHistoryStringsEn.actionViewReview),
          ),
        if (actions.canViewRefund)
          OutlinedButton(
            onPressed: () => onViewRefund(record),
            style: softStyle,
            child: const Text(TripHistoryStringsEn.actionViewRefundStatus),
          ),
        if (record is BookingTripRecord && openNotice != null)
          OutlinedButton.icon(
            key: const Key('trip-emergency-notice'),
            onPressed: () => openNotice(record),
            icon: Icon(Icons.warning_amber_rounded, size: 15, color: p.error),
            label: const Text(TripHistoryStringsEn.actionViewEmergencyNotice),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.error,
              backgroundColor: p.errorBg,
              side: BorderSide(color: p.error.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
