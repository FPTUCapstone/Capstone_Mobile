import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

enum ItineraryStopAction { replace, remove, reviews }

/// One timeline entry of the itinerary detail page: numbered marker + connector,
/// time range, category/mandatory pills, explanation quote, price, shift badge,
/// and "⋯" actions menu.
final class ItineraryStopCard extends StatelessWidget {
  const ItineraryStopCard({
    required this.item,
    this.stopNumber,
    this.shiftMinutes,
    this.actions = const {},
    this.onAction,
    this.isHighlighted = false,
    this.showTimelineConnector = false,
    this.onTap,
    this.onOpenDetail,
    this.provenanceTag,
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
  final bool showTimelineConnector;
  final VoidCallback? onTap;
  final VoidCallback? onOpenDetail;
  final String? provenanceTag;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final isRest = item.itemKind == ItineraryItemKind.rest;
    final shift = shiftMinutes;
    final onAction = this.onAction;

    final markerColor = isRest
        ? palette.secondary
        : (item.isFood ? palette.accent : palette.primary);

    final card = Material(
      color: isHighlighted ? palette.softAccent : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isHighlighted ? palette.primary : palette.border,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tripClock(item.plannedArrival),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                              ),
                            ),
                            Text(
                              ' – ${tripClock(item.plannedDeparture)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: palette.secondary,
                              ),
                            ),
                          ],
                        ),
                        if (item.isMandatory)
                          _StopPill(
                            label: 'Điểm bắt buộc',
                            bg: palette.softAccent,
                            fg: palette.primary,
                          )
                        else if (!isRest)
                          _StopPill(
                            label: item.isFood ? 'Ẩm thực' : 'Điểm tham quan',
                            bg: item.isFood
                                ? palette.warningBg
                                : palette.softAccent,
                            fg: item.isFood
                                ? palette.warningText
                                : palette.primary,
                          )
                        else
                          _StopPill(
                            label: 'Dừng nghỉ',
                            bg: palette.canvas,
                            fg: palette.secondary,
                          ),
                        if (item.category case final category?)
                          _StopPill(
                            label: category,
                            bg: palette.canvas,
                            fg: palette.secondary,
                          ),
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty && onAction != null)
                    PopupMenuButton<ItineraryStopAction>(
                      tooltip: 'Tùy chọn cho ${item.poiName ?? 'địa điểm này'}',
                      icon: Icon(
                        Icons.more_horiz,
                        size: 20,
                        color: palette.secondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
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
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRest ? 'Nghỉ ngơi' : (item.poiName ?? 'Điểm tham quan'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: palette.border, width: 2),
                        ),
                      ),
                      child: Text(
                        isRest
                            ? (item.poiName ??
                                  item.recommendationReason ??
                                  'Thời gian nghỉ')
                            : (stopExplanationText(
                                    friendlyExplanation:
                                        item.friendlyExplanation,
                                    recommendationReason:
                                        item.recommendationReason,
                                  ) ??
                                  'Địa điểm gợi ý'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.secondary,
                          height: 1.38,
                        ),
                      ),
                    ),
                    if (item.isUnavailable) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Địa điểm này hiện không hoạt động.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.error,
                        ),
                      ),
                    ],
                    if (shift != null && shift != 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
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
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: palette.accent,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Divider(color: palette.border, height: 1),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Thời gian dừng:',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.secondary,
                          ),
                        ),
                        Text(
                          '${item.stayDurationMinutes} phút',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        if (!isRest && provenanceTag != null)
                          _StopPill(
                            label: provenanceTag!,
                            bg: palette.softAccent,
                            fg: palette.primary,
                          ),
                      ],
                    ),
                    if (!isRest) ...[
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              visitPriceLabel(
                                item.estimatedCost,
                                item.costKind,
                              ),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: palette.secondary,
                              ),
                            ),
                          ),
                          if (onOpenDetail != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: onOpenDetail,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Text(
                                  'Chi tiết địa điểm →',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (stopNumber == null && !isRest && !showTimelineConnector) {
      return card;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                  ),
                  child: stopNumber != null
                      ? Text(
                          '$stopNumber',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.coffee_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                ),
                if (showTimelineConnector)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 4),
                      color: palette.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: card),
        ],
      ),
    );
  }
}

final class _StopPill extends StatelessWidget {
  const _StopPill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
