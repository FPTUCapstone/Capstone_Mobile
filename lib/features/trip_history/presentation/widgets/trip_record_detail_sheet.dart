import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/widgets/post_trip_complaint_entry_action.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

/// The trip detail behind "View details" and "View refund" (UC-32). The detail
/// is fetched when the sheet opens; nothing here is derived on the device.
class TripRecordDetailSheet extends StatelessWidget {
  const TripRecordDetailSheet({
    required this.title,
    this.highlightRefund = false,
    super.key,
  });

  final String title;

  /// Marks the refund section when the sheet was opened from the refund action.
  final bool highlightRefund;

  static Future<void> show(
    BuildContext context, {
    required TripRecord record,
    required bool isDemo,
    bool highlightRefund = false,
  }) {
    final p = CoastalPalette.of(context);
    final displayTitle = switch (record) {
      BookingTripRecord() => record.title,
      ItineraryTripRecord() => formatTripDisplayTitle(
        title: record.title,
        validFrom: record.departureAtUtc,
      ),
    };
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider(
        create: (_) => serviceLocator<TripRecordDetailCubit>(
          param1: TripRecordRef(kind: record.kind, id: record.id),
          param2: isDemo,
        )..load(),
        child: TripRecordDetailSheet(
          title: displayTitle,
          highlightRefund: highlightRefund,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = isDark ? p.border : const Color(0xFFEDEAE1);

    return ColoredBox(
      color: p.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: TripHistoryStringsEn.actionClose,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 20, color: p.secondary),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, thickness: 1, color: hairline),
                    const SizedBox(height: 14),
                    BlocBuilder<TripRecordDetailCubit, TripRecordDetailState>(
                      builder: (context, state) => switch (state.status) {
                        TripRecordDetailStatus.loading => const _Loading(),
                        TripRecordDetailStatus.failure => _Failure(
                          state: state,
                        ),
                        TripRecordDetailStatus.ready => _Content(
                          detail: state.detail!,
                          highlightRefund: highlightRefund,
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: p.primary),
            const SizedBox(height: 12),
            Text(
              TripHistoryStringsEn.detailLoading,
              style: TextStyle(fontSize: 13, color: p.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.state});

  final TripRecordDetailState state;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.errorBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.message ?? TripHistoryStringsEn.errorMessageGeneric,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: p.error,
              ),
            ),
            if (state.canRetry) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: context.read<TripRecordDetailCubit>().retry,
                style: FilledButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text(TripHistoryStringsEn.actionRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail, required this.highlightRefund});

  final TripRecordDetail detail;
  final bool highlightRefund;

  @override
  Widget build(BuildContext context) {
    return switch (detail) {
      final BookingTripDetail booking => _BookingContent(
        detail: booking,
        highlightRefund: highlightRefund,
      ),
      final ItineraryTripDetail itinerary => _ItineraryContent(
        detail: itinerary,
      ),
    };
  }
}

class _BookingContent extends StatelessWidget {
  const _BookingContent({required this.detail, required this.highlightRefund});

  final BookingTripDetail detail;
  final bool highlightRefund;

  @override
  Widget build(BuildContext context) {
    final people = detail.participants;
    final counts = [
      if (people.adult > 0) TripHistoryStringsEn.formatAdults(people.adult),
      if (people.child > 0) TripHistoryStringsEn.formatChildren(people.child),
      if (people.infant > 0) TripHistoryStringsEn.formatInfants(people.infant),
    ];
    final cancellation = detail.cancellation;
    final refund = detail.refund;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: TripHistoryStringsEn.tourSectionTitle,
          children: [
            _Row(
              TripHistoryStringsEn.labelDestination,
              detail.tour.destinationSummary,
            ),
          ],
        ),
        _Section(
          title: TripHistoryStringsEn.scheduleSectionTitle,
          children: [
            _Row(
              TripHistoryStringsEn.labelStarts,
              TripFormatters.formatVietnamDateTime(detail.schedule.startAtUtc),
            ),
            _Row(
              TripHistoryStringsEn.labelEnds,
              TripFormatters.formatVietnamDateTime(detail.schedule.endAtUtc),
            ),
            if (detail.schedule.meetingPoint != null)
              _Row(
                TripHistoryStringsEn.labelMeetingPoint,
                detail.schedule.meetingPoint!,
              ),
          ],
        ),
        _Section(
          title: TripHistoryStringsEn.participantsSectionTitle,
          children: [for (final text in counts) _Line(text)],
        ),
        if (cancellation != null)
          _Section(
            title: TripHistoryStringsEn.cancellationSectionTitle,
            children: [
              if (cancellation.cancelledAtUtc != null)
                _Row(
                  TripHistoryStringsEn.labelCancelledOn,
                  TripFormatters.formatVietnamDate(
                    cancellation.cancelledAtUtc!,
                  ),
                ),
              if (cancellation.reason != null)
                _Row(
                  TripHistoryStringsEn.labelCancelReason,
                  cancellation.reason!,
                ),
            ],
          ),
        if (refund != null)
          _Section(
            key: highlightRefund
                ? const Key('trip-detail-refund-highlighted')
                : const Key('trip-detail-refund'),
            title: TripHistoryStringsEn.refundSectionTitle,
            highlighted: highlightRefund,
            children: [
              _Row(
                TripHistoryStringsEn.labelStatus,
                TripHistoryStringsEn.refundStatusLabel(refund.status),
              ),
              _Row(
                TripHistoryStringsEn.labelRefundAmount,
                TripFormatters.formatVnd(refund.amount),
              ),
              _Row(
                TripHistoryStringsEn.labelRefundChannel,
                refund.channel ?? TripHistoryStringsEn.channelUnavailable,
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PostTripComplaintEntryAction(
            bookingId: detail.record.reviewableRecord.id,
          ),
        ),
      ],
    );
  }
}

class _ItineraryContent extends StatelessWidget {
  const _ItineraryContent({required this.detail});

  final ItineraryTripDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = isDark ? p.border : const Color(0xFFEDEAE1);
    final record = detail.record;
    final session = detail.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (record.visitedCount != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              TripHistoryStringsEn.formatVisitedOf(
                record.visitedCount!,
                record.stopCount,
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.secondary,
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            TripHistoryStringsEn.stopsSectionTitle,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: p.secondary,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < detail.stops.length; i++) ...[
                _StopTile(stop: detail.stops[i], index: i + 1),
                if (i < detail.stops.length - 1)
                  Divider(height: 1, thickness: 1, color: hairline),
              ],
            ],
          ),
        ),

        if (session != null)
          _Section(
            title: TripHistoryStringsEn.sessionSectionTitle,
            children: [
              _Row(
                TripHistoryStringsEn.labelSessionStarted,
                TripFormatters.formatVietnamDateTime(session.startedAtUtc),
              ),
              if (session.endedAtUtc != null)
                _Row(
                  TripHistoryStringsEn.labelSessionEnded,
                  TripFormatters.formatVietnamDateTime(session.endedAtUtc!),
                ),
              if (session.completionReason != null)
                _Row(
                  TripHistoryStringsEn.labelSessionReason,
                  TripHistoryStringsEn.completionReasonLabel(
                    session.completionReason!,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({required this.stop, required this.index});

  final TripStopDetail stop;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    final visit = stop.visitStatus;
    final arrival = stop.plannedArrivalUtc;
    final departure = stop.plannedDepartureUtc;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      stop.poiName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    if (visit != null) _VisitBadge(status: visit),
                  ],
                ),
                if (arrival != null && departure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      TripHistoryStringsEn.formatPlannedWindow(
                        TripFormatters.formatVietnamTime(arrival),
                        TripFormatters.formatVietnamTime(departure),
                      ),
                      style: TextStyle(fontSize: 12, color: p.secondary),
                    ),
                  ),
                if (stop.reachedAtUtc != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      TripHistoryStringsEn.formatReachedAt(
                        TripFormatters.formatVietnamDateTime(
                          stop.reachedAtUtc!,
                        ),
                      ),
                      style: TextStyle(fontSize: 12, color: p.secondary),
                    ),
                  ),
                if (stop.skippedAtUtc != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      TripHistoryStringsEn.formatSkippedAt(
                        TripFormatters.formatVietnamDateTime(
                          stop.skippedAtUtc!,
                        ),
                      ),
                      style: TextStyle(fontSize: 12, color: p.secondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitBadge extends StatelessWidget {
  const _VisitBadge({required this.status});

  final TripVisitStatus status;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    final (label, bg, fg) = switch (status) {
      TripVisitStatus.reached => (
        TripHistoryStringsEn.stopVisited,
        p.softAccent,
        p.primary,
      ),
      TripVisitStatus.skipped => (
        TripHistoryStringsEn.stopSkipped,
        p.warningBg,
        p.warningText,
      ),
      TripVisitStatus.pending => (
        TripHistoryStringsEn.stopNotVisited,
        p.canvas,
        p.secondary,
      ),
    };
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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.highlighted = false,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: p.secondary,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: highlighted ? p.softAccent : p.canvas,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlighted
                    ? p.primary
                    : p.border.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: p.secondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
      ),
    );
  }
}
