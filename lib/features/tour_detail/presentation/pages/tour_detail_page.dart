import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_day.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_review_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_state.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';

class TourDetailPage extends StatelessWidget {
  const TourDetailPage({
    required this.tourId,
    this.initialSummary,
    this.isDemoMode = false,
    super.key,
  });

  final String tourId;
  final TourSummary? initialSummary;
  final bool isDemoMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TourDetailCubit(
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
        title: const Text('Chi tiết Tour'),
        backgroundColor: Colors.white,
        foregroundColor: TourSearchPalette.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Trở về',
          onPressed: () {
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
            child: CircularProgressIndicator(color: TourSearchPalette.teal),
          ),
          TourDetailStatus.error => _TourDetailErrorView(
            message: state.errorMessage ?? TourDetailState.msg127,
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
  const _TourDetailErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Không thể tải chi tiết tour',
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
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
              ),
            ),
          ],
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
                        'Chi tiết tour đang kết nối máy chủ',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Dữ liệu chi tiết lịch trình theo ngày, lịch khởi hành và danh sách đánh giá sẽ tự động hiển thị khi API Backend hoàn tất tích hợp.',
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
                        'Điểm đến: ${summary!.destinations.join(" • ")}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: TourSearchPalette.muted,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Đơn vị tổ chức: ${summary!.operatorName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: TourSearchPalette.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Giá từ: ${_formatVnd(summary!.basePrice)}',
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
              label: const Text('Quay lại danh sách tour'),
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
                        '${detail.durationDays} ngày',
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
                Text(
                  detail.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: TourSearchPalette.navyLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Departure Schedules Selector ──────────────────────────
                _DepartureSchedulesSection(
                  schedules: detail.schedules,
                  selectedScheduleId: state.selectedScheduleId,
                  scheduleError: state.scheduleError,
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
                _CancellationPolicySection(policy: detail.cancellationPolicy),
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
    required this.onSelect,
  });

  final List<TourScheduleItem> schedules;
  final String? selectedScheduleId;
  final String? scheduleError;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lịch khởi hành có sẵn',
          style: theme.textTheme.titleMedium?.copyWith(
            color: TourSearchPalette.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (schedules.isEmpty)
          const Text('Hiện chưa có lịch khởi hành nào.')
        else
          Column(
            children: schedules.map((schedule) {
              final isSelected = schedule.scheduleId == selectedScheduleId;
              final isSoldOut = schedule.isSoldOut;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: InkWell(
                  key: Key('schedule-${schedule.scheduleId}'),
                  onTap: () => onSelect(schedule.scheduleId),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isSoldOut
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFF0FDF4))
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? (isSoldOut
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF22C55E))
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                          color: isSelected
                              ? (isSoldOut
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF16A34A))
                              : Colors.grey,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(schedule.departureAtUtc),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSoldOut
                                      ? Colors.grey
                                      : TourSearchPalette.navy,
                                ),
                              ),
                              Text(
                                _formatVnd(schedule.price),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSoldOut
                                      ? Colors.grey
                                      : TourSearchPalette.teal,
                                  fontWeight: FontWeight.w600,
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
                            color: isSoldOut
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSoldOut
                                ? 'Hết chỗ'
                                : 'Còn ${schedule.remainingSlots} chỗ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSoldOut
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

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
          'Lịch trình chi tiết',
          style: theme.textTheme.titleMedium?.copyWith(
            color: TourSearchPalette.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
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
                          'Ngày ${day.dayNumber}',
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
                          day.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TourSearchPalette.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    day.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: TourSearchPalette.navyLight,
                      height: 1.4,
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dịch vụ & Tiện ích',
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
              const Text(
                'Bao gồm:',
                style: TextStyle(
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
              const Divider(height: 24),
              const Text(
                'Không bao gồm:',
                style: TextStyle(
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
  const _CancellationPolicySection({required this.policy});

  final String policy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chính sách hoàn huỷ',
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
          child: Text(
            policy,
            style: theme.textTheme.bodySmall?.copyWith(
              color: TourSearchPalette.navyLight,
              height: 1.5,
            ),
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Đánh giá từ du khách',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: TourSearchPalette.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (averageRating != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '★ ${averageRating!.toStringAsFixed(1)} ($reviewCount)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Canonical MSG128 when reviews list is empty ─────────────────
        if (reviews.isEmpty)
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
    final isSoldOut = selectedSchedule?.isSoldOut ?? false;

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
                  'Giá vé',
                  style: TextStyle(
                    fontSize: 11,
                    color: TourSearchPalette.muted,
                  ),
                ),
                Text(
                  _formatVnd(price),
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
              onPressed: isSoldOut
                  ? null
                  : () => _handleBookNow(context, state),
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: Text(isSoldOut ? 'Hết chỗ' : 'Đặt tour ngay'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBookNow(BuildContext context, TourDetailState state) {
    if (!state.isDemoMode) {
      // Production mode: UC-27 is pending server integration.
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đặt Tour (UC-27)'),
          content: const Text(
            'Tính năng đặt tour trực tuyến đang trong giai đoạn phát triển. Bạn có thể liên hệ trực tiếp đơn vị tổ chức để được hỗ trợ.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    // Demo Mode: Check authorization boundary.
    final authSession = context.read<AuthSessionCubit>().state;
    if (!authSession.isAuthenticated) {
      // Guest: Prompt login.
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Yêu cầu đăng nhập'),
          content: const Text(
            'Bạn cần đăng nhập tài khoản Khách du lịch để tiếp tục đặt tour.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push(AppRoutes.login);
              },
              child: const Text('Đăng nhập'),
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
          title: const Text('Quy trình Đặt Tour'),
          content: Text(
            'Bạn đã chọn:\n• Tour: ${detail.title}\n• Lịch: ${schedule != null ? _formatDate(schedule.departureAtUtc) : "Mặc định"}\n• Giá: ${_formatVnd(schedule?.price ?? detail.basePrice)}\n\nLưu ý: Quy trình xác nhận và thanh toán sẽ có sẵn trong UC-27 & UC-28.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
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
                  'DEMO SIMULATION CONTROLS (Debug Mode Only)',
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
                  label: const Text('Có sẵn', style: TextStyle(fontSize: 11)),
                  onPressed: () => cubit.load('demo-tour-1'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text(
                    'Không có đánh giá (MSG128)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateNoReviews,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text(
                    'Hết chỗ (MSG65)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateSoldOut,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text(
                    'Lỗi tải (MSG127)',
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

String _formatVnd(int price) {
  final text = price.toString();
  final buffer = StringBuffer();
  final length = text.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(text[i]);
  }
  buffer.write('₫');
  return buffer.toString();
}

String _formatDate(DateTime dateUtc) {
  final vn = dateUtc.add(const Duration(hours: 7));
  final day = vn.day.toString().padLeft(2, '0');
  final month = vn.month.toString().padLeft(2, '0');
  return '$day/$month/${vn.year}';
}
