import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

/// "Vé · Ăn uống · Tổng / ngân sách" split computed from each stop's cost
/// kind. Stops without a known price are not counted as free: the card says
/// how many are left out.
final class ItineraryCostSummary extends StatelessWidget {
  const ItineraryCostSummary({required this.detail, super.key});

  final ItineraryDetail detail;

  @override
  Widget build(BuildContext context) {
    var tickets = 0.0;
    var food = 0.0;
    var unknown = 0;
    for (final item in detail.visitItems) {
      final cost = item.estimatedCost;
      if (cost == null) {
        unknown++;
      } else if (item.isFood) {
        food += cost;
      } else {
        tickets += cost;
      }
    }
    final theme = Theme.of(context);
    final budget = detail.budgetVnd;
    Widget cell(
      String label,
      double amount, {
      bool strong = false,
      double? budget,
      int flex = 1,
    }) => Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            budget == null ? label : '$label / ngân sách',
            style: theme.textTheme.labelMedium,
          ),
          Text(
            budget == null
                ? formatVnd(amount)
                : '${formatVnd(amount)} / ${formatVnd(budget)}',
            style: strong
                ? theme.textTheme.titleSmall
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      key: const Key('cost_summary'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                cell('Vé', tickets),
                cell('Ăn uống', food),
                cell(
                  'Tổng',
                  tickets + food,
                  strong: true,
                  budget: budget,
                  flex: budget == null ? 1 : 2,
                ),
              ],
            ),
            if (unknown > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Chưa tính $unknown điểm chưa có giá',
                  style: muted,
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Chi phí dự kiến cho mỗi người · '
              '${tripDuration(detail.totalDurationMinutes)}',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}
