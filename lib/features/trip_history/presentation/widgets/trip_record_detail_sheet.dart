import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => serviceLocator<TripRecordDetailCubit>(
          param1: TripRecordRef(kind: record.kind, id: record.id),
          param2: isDemo,
        )..load(),
        child: TripRecordDetailSheet(
          title: record.title,
          highlightRefund: highlightRefund,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: TripHistoryStringsEn.actionClose,
              icon: const Icon(Icons.close),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  BlocBuilder<TripRecordDetailCubit, TripRecordDetailState>(
                    builder: (context, state) => switch (state.status) {
                      TripRecordDetailStatus.loading => const _Loading(),
                      TripRecordDetailStatus.failure => _Failure(state: state),
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
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.sm),
            Text(TripHistoryStringsEn.detailLoading),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.message ?? TripHistoryStringsEn.errorMessageGeneric,
            style: const TextStyle(color: AppColors.error),
          ),
          if (state.canRetry) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: context.read<TripRecordDetailCubit>().retry,
              icon: const Icon(Icons.refresh),
              label: const Text(TripHistoryStringsEn.actionRetry),
            ),
          ],
        ],
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
      ],
    );
  }
}

class _ItineraryContent extends StatelessWidget {
  const _ItineraryContent({required this.detail});

  final ItineraryTripDetail detail;

  @override
  Widget build(BuildContext context) {
    final record = detail.record;
    final session = detail.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (record.visitedCount != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              TripHistoryStringsEn.formatVisitedOf(
                record.visitedCount!,
                record.stopCount,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
        _Section(
          title: TripHistoryStringsEn.stopsSectionTitle,
          children: [for (final stop in detail.stops) _StopTile(stop: stop)],
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
  const _StopTile({required this.stop});

  final TripStopDetail stop;

  @override
  Widget build(BuildContext context) {
    final visit = stop.visitStatus;
    final arrival = stop.plannedArrivalUtc;
    final departure = stop.plannedDepartureUtc;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    stop.poiName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (visit != null)
                    StatusBadge(
                      label: switch (visit) {
                        TripVisitStatus.reached =>
                          TripHistoryStringsEn.stopVisited,
                        TripVisitStatus.skipped =>
                          TripHistoryStringsEn.stopSkipped,
                        TripVisitStatus.pending =>
                          TripHistoryStringsEn.stopNotVisited,
                      },
                      type: switch (visit) {
                        TripVisitStatus.reached => StatusBadgeType.success,
                        TripVisitStatus.skipped => StatusBadgeType.warning,
                        TripVisitStatus.pending => StatusBadgeType.neutral,
                      },
                    ),
                ],
              ),
              if (arrival != null && departure != null)
                _Line(
                  TripHistoryStringsEn.formatPlannedWindow(
                    TripFormatters.formatVietnamTime(arrival),
                    TripFormatters.formatVietnamTime(departure),
                  ),
                ),
              if (stop.reachedAtUtc != null)
                _Line(
                  TripHistoryStringsEn.formatReachedAt(
                    TripFormatters.formatVietnamDateTime(stop.reachedAtUtc!),
                  ),
                ),
              if (stop.skippedAtUtc != null)
                _Line(
                  TripHistoryStringsEn.formatSkippedAt(
                    TripFormatters.formatVietnamDateTime(stop.skippedAtUtc!),
                  ),
                ),
            ],
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlighted ? AppColors.secondary : AppColors.line,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                ...children,
              ],
            ),
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            flex: 3,
            child: Text(value, style: const TextStyle(fontSize: 13)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    );
  }
}
