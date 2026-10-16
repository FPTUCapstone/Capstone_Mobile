import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

enum ItineraryStopAction { replace, remove, reviews }

/// One timeline entry of the itinerary detail page: time, place, price,
/// reason, a "moved" badge after an edit, and the "⋯" actions menu.
final class ItineraryStopCard extends StatelessWidget {
  const ItineraryStopCard({
    required this.item,
    this.stopNumber,
    this.shiftMinutes,
    this.actions = const {},
    this.onAction,
    this.isHighlighted = false,
    this.onTap,
    super.key,
  });

  final ItineraryDetailItem item;

  /// Number shown on the map marker of this stop.
  final int? stopNumber;

  /// Minutes the arrival moved in the last edit (positive = later).
  final int? shiftMinutes;
  final Set<ItineraryStopAction> actions;
  final ValueChanged<ItineraryStopAction>? onAction;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRest = item.itemKind == ItineraryItemKind.rest;
    final shift = shiftMinutes;
    final onAction = this.onAction;
    return Card(
      color: isHighlighted ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tripClock(item.plannedArrival),
                      style: theme.textTheme.labelLarge,
                    ),
                    if (stopNumber case final number?)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: item.isFood
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.primary,
                          child: Text(
                            '$number',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRest ? 'Nghỉ ngơi' : (item.poiName ?? 'Điểm tham quan'),
                      style: theme.textTheme.titleSmall,
                    ),
                    if (item.category != null) Text(item.category!),
                    if (!isRest)
                      Text(
                        visitPriceLabel(item.estimatedCost, item.costKind),
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isRest
                          ? (item.poiName ??
                                item.recommendationReason ??
                                'Thời gian nghỉ')
                          : (item.recommendationReason ?? 'Địa điểm gợi ý'),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (item.isMandatory) const Text('Điểm bắt buộc'),
                    if (item.isUnavailable)
                      Text(
                        'Địa điểm này hiện không hoạt động.',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    if (shift != null && shift != 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        // The "⟲" glyph is decoration: screen readers hear
                        // "Giờ đến lùi 25 phút".
                        child: Semantics(
                          container: true,
                          label: shift > 0
                              ? 'Giờ đến lùi ${vietnameseDuration(shift)}'
                              : 'Giờ đến sớm ${vietnameseDuration(shift)}',
                          excludeSemantics: true,
                          child: Text(
                            shift > 0
                                ? '⟲ lùi ${vietnameseDuration(shift)}'
                                : '⟲ sớm ${vietnameseDuration(shift)}',
                            key: ValueKey('shift_badge_${item.itemId}'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${item.stayDurationMinutes} phút'),
                  if (actions.isNotEmpty && onAction != null)
                    PopupMenuButton<ItineraryStopAction>(
                      tooltip: 'Tùy chọn cho ${item.poiName ?? 'địa điểm này'}',
                      icon: const Icon(Icons.more_horiz),
                      onSelected: onAction,
                      itemBuilder: (_) => [
                        for (final action in ItineraryStopAction.values)
                          if (actions.contains(action))
                            PopupMenuItem(
                              value: action,
                              child: Text(switch (action) {
                                ItineraryStopAction.replace => 'Thay địa điểm',
                                ItineraryStopAction.remove => 'Bỏ khỏi lịch',
                                ItineraryStopAction.reviews => 'Xem đánh giá',
                              }),
                            ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
