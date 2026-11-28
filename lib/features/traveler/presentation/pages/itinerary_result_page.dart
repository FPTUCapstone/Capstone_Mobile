import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';

final class ItineraryResultPage extends StatelessWidget {
  const ItineraryResultPage({required this.itinerary, super.key});

  final GeneratedItinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final theme = Theme.of(context);
    final totalCost = itinerary.totalEstimatedCost;
    final hasKnownCost = totalCost >= 0;

    return AppPageScaffold(
      title: 'Lịch trình của bạn',
      content: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                itinerary.title,
                style: TextStyle(
                  fontFamily: AppTypography.displayFont,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _SummaryRow(
                durationMinutes: itinerary.totalDurationMinutes,
                estimatedCost: hasKnownCost ? totalCost : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Chi phí chỉ là ước tính vé tham quan các điểm đến.',
                style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var index = 0; index < itinerary.items.length; index++) ...[
          if (_spansDays(itinerary.items) &&
              (index == 0 ||
                  !sameTripDay(
                    itinerary.items[index - 1].plannedArrival,
                    itinerary.items[index].plannedArrival,
                  )))
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.tealSoftContainer,
                      borderRadius: BorderRadius.circular(TripMateRadius.pill),
                    ),
                    child: Text(
                      tripDate(itinerary.items[index].plannedArrival),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: c.brandTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (index > 0 &&
              itinerary.items[index - 1].travelDurationToNextMinutes != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                top: 2,
                bottom: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_walk_rounded,
                    size: 14,
                    color: c.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Di chuyển: ${itinerary.items[index - 1].travelDurationToNextMinutes} phút',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ItineraryItemCard(item: itinerary.items[index]),
          ),
        ],
      ],
      footer: Builder(
        builder: (context) {
          final isActive = itinerary.status.trim().toLowerCase() == 'active';

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: isActive
                    ? () => context.push(
                        AppRoutes.activeTripLive(itinerary.itineraryId),
                        extra: itinerary.title,
                      )
                    : null,
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Bắt đầu dẫn đường'),
              ),
              if (!isActive) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Cần lịch trình đang hoạt động để dẫn đường (hiện tại: ${itineraryStatusLabel(itinerary.status)}). Hãy chấp nhận lịch trình để kích hoạt.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '${AppRoutes.activeTripLive(itinerary.itineraryId)}?demo=true',
                    extra: itinerary.title,
                  ),
                  icon: Icon(Icons.bug_report_outlined, color: c.warning),
                  label: const Text('Xem thử dẫn đường (Demo)'),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => context.push(
                  AppRoutes.offlinePackage(itinerary.itineraryId),
                  extra: itinerary.title,
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Tải về xem ngoại tuyến'),
              ),
              const SizedBox(height: AppSpacing.xxs),
              TextButton(
                onPressed: () => context.go(AppRoutes.createItinerary),
                child: const Text('Tạo lịch trình khác'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────── Helpers ────────────────────────────────── //

String _formatDuration(int minutes) => tripDuration(minutes);

bool _spansDays(List<GeneratedItineraryItem> items) =>
    items.isNotEmpty &&
    !sameTripDay(items.first.plannedArrival, items.last.plannedDeparture);

/// Formats a [DateTime] as Vietnam-time "HH:mm".
String _formatTime(DateTime utc) => tripClock(utc);

// ──────────────────────────────── Widgets ───────────────────────────────── //

final class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.durationMinutes, this.estimatedCost});

  final int durationMinutes;
  final double? estimatedCost;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final parts = [
      _formatDuration(durationMinutes),
      if (estimatedCost != null) 'Dự kiến ${formatVnd(estimatedCost!)}',
    ];
    return Row(
      children: [
        Icon(Icons.schedule_outlined, size: 15, color: c.brandTeal),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            parts.join(' · '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.brandTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

final class _ItineraryItemCard extends StatelessWidget {
  const _ItineraryItemCard({required this.item});

  final GeneratedItineraryItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final theme = Theme.of(context);
    final isRest = item.itemKind == ItineraryItemKind.rest;
    final arrivalText = _formatTime(item.plannedArrival);
    final departureText = _formatTime(item.plannedDeparture);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimeColumn(arrival: arrivalText, departure: departureText),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isRest
                            ? c.coralSoftContainer
                            : c.tealSoftContainer,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        isRest ? Icons.coffee_outlined : Icons.place_outlined,
                        size: 15,
                        color: isRest ? c.brandCoral : c.brandTeal,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          isRest
                              ? 'Nghỉ ngơi gợi ý'
                              : (item.poiName ?? 'Điểm tham quan'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!isRest && item.isMandatory) _MandatoryBadge(),
                    Text(
                      isRest
                          ? 'Chưa bao gồm chi phí ăn uống.'
                          : _subtitleText(item),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
                if (!isRest && item.estimatedCost != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Dự kiến ${formatVnd(item.estimatedCost!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.brandTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${item.stayDurationMinutes} phút',
            style: theme.textTheme.bodySmall?.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleText(GeneratedItineraryItem item) {
    if (item.isMandatory) return 'Điểm đến không thể bỏ lỡ';
    if (item.recommendationReason != null) return item.recommendationReason!;
    return 'Điểm gợi ý lân cận';
  }
}

final class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.arrival, required this.departure});

  final String arrival;
  final String departure;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final style = Theme.of(context).textTheme.bodySmall;
    return SizedBox(
      width: 44,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            arrival,
            style: style?.copyWith(
              color: c.brandTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(departure, style: style?.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

final class _MandatoryBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.coralSoftContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Điểm nổi bật',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: c.coralAccessibleText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
