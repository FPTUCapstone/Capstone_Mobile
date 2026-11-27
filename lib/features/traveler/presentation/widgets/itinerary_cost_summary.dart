import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

/// 2x2 KPI summary grid matching Web `ItinerarySummaryCards`:
/// 1) Tổng thời lượng  2) Chi phí dự kiến / người (Vé · Ăn uống + unknown note)
/// 3) Số điểm dừng     4) Nguồn lịch trình (tinted soft sage).
final class ItineraryCostSummary extends StatelessWidget {
  const ItineraryCostSummary({required this.detail, super.key});

  final ItineraryDetail detail;

  @override
  Widget build(BuildContext context) {
    var tickets = 0.0;
    var food = 0.0;
    var unknown = 0;
    final visits = detail.visitItems;
    final restCount = detail.items.length - visits.length;
    for (final item in visits) {
      final cost = item.estimatedCost;
      if (cost == null) {
        unknown++;
      } else if (item.isFood) {
        food += cost;
      } else {
        tickets += cost;
      }
    }
    final palette = CoastalPalette.of(context);
    final budget = detail.budgetVnd;
    final provenance = detail.provenance;

    final (sourceTitle, sourceSubtitle) = switch (provenance) {
      ScheduleProvenance(solverOutcome: 'manual_order') => (
        'Thứ tự bạn chỉnh',
        'Lịch theo thứ tự đã sửa',
      ),
      ScheduleProvenance(isHeuristicFallback: true) => (
        'Chế độ nhanh',
        'Lịch lập theo chế độ nhanh',
      ),
      _ => ('AI đề xuất', 'Tối ưu hóa tự động'),
    };

    final labelStyle = TextStyle(fontSize: 10.5, color: palette.secondary);
    final subStyle = TextStyle(
      fontSize: 10.5,
      color: palette.secondary,
      height: 1.3,
    );
    final valueStyle = TextStyle(
      fontFamily: AppTypography.displayFont,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: palette.ink,
      height: 1.2,
    );

    return Container(
      key: const Key('cost_summary'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tổng thời lượng', style: labelStyle),
                        const SizedBox(height: 4),
                        Text(
                          vietnameseDuration(detail.totalDurationMinutes),
                          style: valueStyle,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${detail.totalDurationMinutes} phút hoạt động',
                          style: subStyle,
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(color: palette.border, width: 1),
                Expanded(
                  flex: budget == null ? 1 : 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget == null
                              ? 'Chi phí dự kiến / người'
                              : 'Tổng / ngân sách',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          budget == null
                              ? formatVnd(tickets + food)
                              : '${formatVnd(tickets + food)} / ${formatVnd(budget)}',
                          style: AppTypography.price(
                            palette.ink,
                            fontSize: budget == null ? 15.5 : 13.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 3,
                          runSpacing: 1,
                          children: [
                            Text('Vé', style: subStyle),
                            Text(
                              formatVnd(tickets),
                              style: subStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: palette.ink,
                              ),
                            ),
                            Text('· Ăn uống', style: subStyle),
                            Text(
                              formatVnd(food),
                              style: subStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: palette.ink,
                              ),
                            ),
                          ],
                        ),
                        if (unknown > 0) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.warningBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Chưa tính $unknown điểm chưa có giá',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: palette.warningText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: palette.border, height: 1),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Số điểm dừng', style: labelStyle),
                        const SizedBox(height: 4),
                        Text('${detail.items.length} điểm', style: valueStyle),
                        const SizedBox(height: 3),
                        Text(
                          restCount > 0
                              ? '${visits.length} tham quan · $restCount dừng nghỉ'
                              : '${visits.length} điểm tham quan',
                          style: subStyle,
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(color: palette.border, width: 1),
                Expanded(
                  flex: budget == null ? 1 : 2,
                  child: ColoredBox(
                    color: palette.softAccent,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nguồn lịch trình', style: labelStyle),
                          const SizedBox(height: 4),
                          Text(
                            sourceTitle,
                            style: valueStyle.copyWith(
                              fontSize: 14.5,
                              color: palette.primary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(sourceSubtitle, style: subStyle),
                        ],
                      ),
                    ),
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
