import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_cancellation_rule.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_day.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_review_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/usecases/get_tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_state.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/formatters/tour_detail_formatters.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/resources/tour_detail_strings.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/widgets/departure_schedule_card.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/widgets/itinerary_stop_tile.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';

class TourDetailPage extends StatelessWidget {
  const TourDetailPage({
    required this.tourId,
    this.initialSummary,
    this.isDemoMode = false,
    @visibleForTesting this.getTourDetail,
    super.key,
  });

  final String tourId;
  final TourSummary? initialSummary;
  final bool isDemoMode;
  final GetTourDetail? getTourDetail;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TourDetailCubit(
        getTourDetail: getTourDetail,
        initialSummary: initialSummary,
        isDemoMode: isDemoMode,
      )..load(tourId),
      child: _TourDetailView(tourId: tourId),
    );
  }
}

class _TourDetailView extends StatelessWidget {
  const _TourDetailView({required this.tourId});

  final String tourId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TourDetailCubit>();
    final state = cubit.state;

    return Scaffold(
      backgroundColor: TourSearchPalette.background,
      appBar: AppBar(
        title: const Text(TourDetailStrings.appBarTitle),
        backgroundColor: Colors.white,
        foregroundColor: TourSearchPalette.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: TourDetailStrings.backTooltip,
          onPressed: () {
            // When entered from Recommendations (?demo=true) or Search, pop()
            // returns directly to the previous route with its query preserved.
            // For direct entry with no Navigator history, fall back to the
            // canonical Tour Search route (which does not use ?demo=true).
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.tourSearch);
            }
          },
        ),
      ),
      body: SafeArea(
        child: switch (state.status) {
          TourDetailStatus.initial || TourDetailStatus.loading => const Center(
            child: CircularProgressIndicator(
              color: TourSearchPalette.teal,
              semanticsLabel: TourDetailStrings.loadingLabel,
            ),
          ),
          TourDetailStatus.error => _TourDetailErrorView(
            message: state.errorMessage ?? TourDetailState.msg127,
            notFound: state.failureKind == TourDetailFailureKind.notFound,
            onRetry: () => cubit.load(tourId),
          ),
          TourDetailStatus.pendingIntegration => _TourDetailPendingView(
            summary: state.initialSummary,
            tourId: tourId,
          ),
          TourDetailStatus.success => _TourDetailSuccessView(
            state: state,
            cubit: cubit,
          ),
        },
      ),
      bottomNavigationBar: state.status == TourDetailStatus.success
          ? _TourDetailBottomBar(state: state)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error View
// ─────────────────────────────────────────────────────────────────────────────

class _TourDetailErrorView extends StatelessWidget {
  const _TourDetailErrorView({
    required this.message,
    required this.notFound,
    required this.onRetry,
  });

  final String message;

  /// The tour is gone or not public: retrying cannot help, so offer a way back
  /// instead of a Retry button.
  final bool notFound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: SingleChildScrollView(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  notFound ? Icons.travel_explore : Icons.cloud_off_outlined,
                  size: 56,
                  color: notFound
                      ? TourSearchPalette.muted
                      : const Color(0xFFDC2626),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  notFound
                      ? TourDetailStrings.notFoundTitle
                      : TourDetailStrings.errorTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: TourSearchPalette.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: TourSearchPalette.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (notFound)
                  OutlinedButton.icon(
                    key: const Key('tour-detail-back-to-list-button'),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.tourSearch);
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text(TourDetailStrings.backToTourList),
                  )
                else
                  FilledButton.icon(
                    key: const Key('tour-detail-retry-button'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text(TourDetailStrings.retry),
                    style: FilledButton.styleFrom(
                      backgroundColor: TourSearchPalette.teal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Integration View (Production Truthful)
// ─────────────────────────────────────────────────────────────────────────────

class _TourDetailPendingView extends StatelessWidget {
  const _TourDetailPendingView({required this.summary, required this.tourId});

  final TourSummary? summary;
  final String tourId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informational Notice Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.hub_outlined,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TourDetailStrings.pendingIntegrationTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        TourDetailStrings.pendingIntegrationDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Available summary metadata card
          if (summary != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: TourSearchPalette.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary!.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: TourSearchPalette.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (summary!.destinations.isNotEmpty)
                      Text(
                        '${TourDetailStrings.destinationsLabel}: ${summary!.destinations.join(" • ")}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: TourSearchPalette.muted,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${TourDetailStrings.operatorLabel}: ${summary!.operatorName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: TourSearchPalette.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${TourDetailStrings.fromPrice}: ${formatVnd(summary!.basePrice)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: TourSearchPalette.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.tourSearch);
                }
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text(TourDetailStrings.backToTourList),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success View (Full Details)
// ─────────────────────────────────────────────────────────────────────────────

class _TourDetailSuccessView extends StatelessWidget {
  const _TourDetailSuccessView({required this.state, required this.cubit});

  final TourDetailState state;
  final TourDetailCubit cubit;

  @override
  Widget build(BuildContext context) {
    final detail = state.tourDetail!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Demo Control Bar (Debug only) ──────────────────────────────
          if (state.isDemoMode && kDebugMode)
            _DemoDetailControlsBar(cubit: cubit),

          // ── Image Gallery ──────────────────────────────────────────────
          _TourImageGallery(images: detail.images),

          // ── Summary & Operator Info ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: TourSearchPalette.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        TourDetailStrings.durationDays(detail.durationDays),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TourSearchPalette.navy,
                        ),
                      ),
                    ),
                    if (detail.averageRating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${detail.averageRating!.toStringAsFixed(1)} (${detail.reviewCount})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        detail.operatorName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_destinationsText(detail) case final destinations?) ...[
                  Text(
                    TourDetailStrings.destinationsLine(destinations),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: TourSearchPalette.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                if (detail.operatorPhone?.trim() case final phone?
                    when phone.isNotEmpty) ...[
                  SelectableText(
                    TourDetailStrings.contactOperatorLine(phone),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: TourSearchPalette.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                if (detail.description.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: TourSearchPalette.navyLight,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),

                // ── Departure Schedules Selector ──────────────────────────
                _DepartureSchedulesSection(
                  schedules: detail.schedules,
                  selectedScheduleId: state.selectedScheduleId,
                  scheduleError: state.scheduleError,
                  asOfUtc: detail.asOfUtc,
                  onSelect: cubit.selectSchedule,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Day-by-day Itinerary ──────────────────────────────────
                _ItinerarySection(itineraryDays: detail.itineraryDays),
                const SizedBox(height: AppSpacing.lg),

                // ── Inclusions & Exclusions ───────────────────────────────
                _InclusionsExclusionsSection(
                  inclusions: detail.inclusions,
                  exclusions: detail.exclusions,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Cancellation Policy ───────────────────────────────────
                _CancellationPolicySection(
                  policy: detail.cancellationPolicy,
                  rules: detail.cancellationRules,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Reviews Section ───────────────────────────────────────
                _ReviewsSection(
                  reviews: detail.reviews,
                  averageRating: detail.averageRating,
                  reviewCount: detail.reviewCount,
                ),
                const SizedBox(height: 80), // space for bottom bar
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image Gallery
// ─────────────────────────────────────────────────────────────────────────────

class _TourImageGallery extends StatefulWidget {
  const _TourImageGallery({required this.images});

  final List<String> images;

  @override
  State<_TourImageGallery> createState() => _TourImageGalleryState();
}

class _TourImageGalleryState extends State<_TourImageGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 220,
        color: const Color(0xFFE2E8F0),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 48, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return Image.network(
                widget.images[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFE2E8F0),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Departure Schedules Section (with MSG65 notice)
// ─────────────────────────────────────────────────────────────────────────────

class _DepartureSchedulesSection extends StatelessWidget {
  const _DepartureSchedulesSection({
    required this.schedules,
    required this.selectedScheduleId,
    required this.scheduleError,
    required this.asOfUtc,
    required this.onSelect,
  });

  final List<TourScheduleItem> schedules;
  final String? selectedScheduleId;
  final String? scheduleError;
  final DateTime? asOfUtc;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TourDetailStrings.schedulesTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: TourSearchPalette.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        if (schedules.isNotEmpty) ...[
          Text(
            TourDetailStrings.vietnamTimeNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: TourSearchPalette.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (schedules.isEmpty)
          const Text(TourDetailStrings.noSchedules)
        else
          Column(
            children: schedules
                .map(
                  (schedule) => DepartureScheduleCard(
                    schedule: schedule,
                    isSelected: schedule.scheduleId == selectedScheduleId,
                    onTap: () => onSelect(schedule.scheduleId),
                  ),
                )
                .toList(),
          ),
        if (schedules.isNotEmpty && asOfUtc != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            TourDetailStrings.asOfNote(formatVietnamDateTime(asOfUtc!)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: TourSearchPalette.muted,
            ),
          ),
        ],

        // ── MSG65 Warning Notice ──────────────────────────────────────
        if (scheduleError != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    scheduleError!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Itinerary Section
// ─────────────────────────────────────────────────────────────────────────────

class _ItinerarySection extends StatelessWidget {
  const _ItinerarySection({required this.itineraryDays});

  final List<TourItineraryDay> itineraryDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TourDetailStrings.itineraryTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: TourSearchPalette.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (itineraryDays.isEmpty) const Text(TourDetailStrings.noItinerary),
        ...itineraryDays.map((day) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: TourSearchPalette.teal,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          TourDetailStrings.dayNumber(day.dayNumber),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          // Real data has no separate day title: avoid "Day 1 Day 1".
                          day.title ==
                                  TourDetailStrings.dayNumber(day.dayNumber)
                              ? ''
                              : day.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TourSearchPalette.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (day.description.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      day.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: TourSearchPalette.navyLight,
                        height: 1.4,
                      ),
                    ),
                  ],
                  ...day.stops.map((stop) => ItineraryStopTile(stop: stop)),
                  if (day.stops.isEmpty &&
                      day.description.trim().isEmpty &&
                      day.activities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        TourDetailStrings.noStopsForDay,
                        style: TextStyle(
                          fontSize: 12,
                          color: TourSearchPalette.muted,
                        ),
                      ),
                    ),
                  if (day.activities.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    ...day.activities.map(
                      (act) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(color: TourSearchPalette.teal),
                            ),
                            Expanded(
                              child: Text(
                                act,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inclusions & Exclusions Section
// ─────────────────────────────────────────────────────────────────────────────

class _InclusionsExclusionsSection extends StatelessWidget {
  const _InclusionsExclusionsSection({
    required this.inclusions,
    required this.exclusions,
  });

  final List<String> inclusions;
  final List<String> exclusions;

  @override
  Widget build(BuildContext context) {
    if (inclusions.isEmpty && exclusions.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TourDetailStrings.servicesTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: TourSearchPalette.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inclusions.isNotEmpty) ...[
                Text(
                  '${TourDetailStrings.inclusionsTitle}:',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                ...inclusions.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (inclusions.isNotEmpty && exclusions.isNotEmpty)
                const Divider(height: 24),
              if (exclusions.isNotEmpty) ...[
                Text(
                  '${TourDetailStrings.exclusionsTitle}:',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                ...exclusions.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.highlight_off,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cancellation Policy Section
// ─────────────────────────────────────────────────────────────────────────────

class _CancellationPolicySection extends StatelessWidget {
  const _CancellationPolicySection({required this.policy, required this.rules});

  final String policy;
  final List<TourCancellationRule> rules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = describeCancellationRules(rules);
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: TourSearchPalette.navyLight,
      height: 1.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TourDetailStrings.cancellationPolicyTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: TourSearchPalette.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: lines.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lines
                      .map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(line, style: textStyle),
                        ),
                      )
                      .toList(),
                )
              : Text(
                  policy.trim().isEmpty
                      ? TourDetailStrings.noCancellationPolicy
                      : policy,
                  style: textStyle,
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reviews Section (with MSG128 if empty)
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.averageRating,
    required this.reviewCount,
  });

  final List<TourReviewItem> reviews;
  final double? averageRating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            Text(
              TourDetailStrings.reviewsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (averageRating != null)
              Text(
                '★ ${averageRating!.toStringAsFixed(1)} ($reviewCount)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Canonical MSG128 when nobody has reviewed the tour ──────────
        if (reviews.isEmpty && reviewCount == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  color: TourSearchPalette.muted,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    TourDetailState.msg128,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: TourSearchPalette.muted,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (reviews.isEmpty)
          Text(
            TourDetailStrings.reviewsAggregateOnly,
            style: theme.textTheme.bodySmall?.copyWith(
              color: TourSearchPalette.muted,
            ),
          )
        else
          Column(
            children: reviews.map((rev) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rev.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: TourSearchPalette.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                rev.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        rev.comment,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: TourSearchPalette.navyLight,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Bottom Bar with Book Now Boundary
// ─────────────────────────────────────────────────────────────────────────────

class _TourDetailBottomBar extends StatelessWidget {
  const _TourDetailBottomBar({required this.state});

  final TourDetailState state;

  @override
  Widget build(BuildContext context) {
    final detail = state.tourDetail!;
    final selectedSchedule = state.selectedSchedule;
    final price = selectedSchedule?.price ?? detail.basePrice;
    // BR-60: only a departure the server says is bookable can be booked.
    final canBook = selectedSchedule?.isSelectable ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  TourDetailStrings.fromPrice,
                  style: TextStyle(
                    fontSize: 11,
                    color: TourSearchPalette.muted,
                  ),
                ),
                Text(
                  formatVnd(price),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TourSearchPalette.teal,
                  ),
                ),
              ],
            ),
            FilledButton(
              key: const Key('tour-detail-book-now-button'),
              onPressed: canBook ? () => _handleBookNow(context, state) : null,
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: Text(
                selectedSchedule == null || canBook
                    ? TourDetailStrings.bookNow
                    : departureStateLabel(selectedSchedule),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBookNow(BuildContext context, TourDetailState state) {
    // BR-54: Guest may view Tour Detail publicly, but authentication is required
    // before a Booking is created.
    final authSession = context.read<AuthSessionCubit>().state;
    if (!authSession.isAuthenticated) {
      // Guest: Prompt login before proceeding to booking.
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(TourDetailStrings.loginRequiredTitle),
          content: const Text(TourDetailStrings.loginRequiredDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(TourDetailStrings.loginLater),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                final returnTarget = AppRoutes.tourDetail(
                  state.tourDetail!.tourId,
                  demo: state.isDemoMode,
                );
                context.push(
                  Uri(
                    path: AppRoutes.login,
                    queryParameters: {'from': returnTarget},
                  ).toString(),
                );
              },
              child: const Text(TourDetailStrings.loginAction),
            ),
          ],
        ),
      );
    } else {
      // Authenticated Traveler: Show boundary explanation without fabricating booking ID.
      final detail = state.tourDetail!;
      final schedule = state.selectedSchedule;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(TourDetailStrings.bookingWorkflowTitle),
          content: Text(
            'Selected:\n• Tour: ${detail.title}\n• Schedule: ${schedule != null ? formatVietnamDate(schedule.departureAtUtc) : "Default"}\n• Price: ${formatVnd(schedule?.price ?? detail.basePrice)}\n\nNotice: Schedule reservation and payment workflow will be available in UC-27 & UC-28.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(TourDetailStrings.close),
            ),
          ],
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo Controls Bar (Debug Only)
// ─────────────────────────────────────────────────────────────────────────────

class _DemoDetailControlsBar extends StatelessWidget {
  const _DemoDetailControlsBar({required this.cubit});

  final TourDetailCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, size: 14, color: Color(0xFFB45309)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  TourDetailStrings.demoControlsTitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  label: const Text(
                    TourDetailStrings.demoChipAvailable,
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () => cubit.load('demo-tour-1'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text(
                    TourDetailStrings.demoChipNoReviews,
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateNoReviews,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text(
                    TourDetailStrings.demoChipSoldOut,
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateSoldOut,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text(
                    TourDetailStrings.demoChipError,
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateError,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String? _destinationsText(TourDetail detail) {
  if (detail.destinations.isNotEmpty) return detail.destinations.join(' • ');
  final summary = detail.destinationSummary.trim();
  return summary.isEmpty ? null : summary;
}
