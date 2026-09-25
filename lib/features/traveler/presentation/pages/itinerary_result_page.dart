import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';

final class ItineraryResultPage extends StatelessWidget {
  const ItineraryResultPage({required this.itinerary, super.key});

  final GeneratedItinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCost = itinerary.totalEstimatedCost;
    final hasKnownCost = totalCost >= 0;

    return AppPageScaffold(
      title: 'Your itinerary',
      content: [
        Text(itinerary.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        _SummaryRow(
          durationMinutes: itinerary.totalDurationMinutes,
          estimatedCost: hasKnownCost ? totalCost : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'All costs are estimates for POI entry fees only.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var index = 0; index < itinerary.items.length; index++) ...[
          if (index > 0 &&
              itinerary.items[index - 1].travelDurationToNextMinutes != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                'Travel: ${itinerary.items[index - 1].travelDurationToNextMinutes} min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ItineraryItemCard(item: itinerary.items[index]),
          ),
        ],
      ],
      footer: FilledButton.tonal(
        onPressed: () => context.go(AppRoutes.createItinerary),
        child: const Text('Create another itinerary'),
      ),
    );
  }
}

// ─────────────────────────────── Helpers ────────────────────────────────── //

String _formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '$h h $m min';
  if (h > 0) return '$h h';
  return '$m min';
}

/// Formats a [double] cost as "₫ 650,000" without requiring `intl`.
String _formatVnd(double amount) {
  final rounded = amount.round();
  final s = rounded.toString();
  final buf = StringBuffer('₫ ');
  final offset = s.length % 3;
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (i - offset) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Formats a local-time [DateTime] as "HH:mm".
String _formatTime(DateTime utc) {
  final vietnamTime = utc.toUtc().add(const Duration(hours: 7));
  final h = vietnamTime.hour.toString().padLeft(2, '0');
  final m = vietnamTime.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// ──────────────────────────────── Widgets ───────────────────────────────── //

final class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.durationMinutes, this.estimatedCost});

  final int durationMinutes;
  final double? estimatedCost;

  @override
  Widget build(BuildContext context) {
    final parts = [
      _formatDuration(durationMinutes),
      if (estimatedCost != null) 'Est. ${_formatVnd(estimatedCost!)}',
    ];
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

final class _ItineraryItemCard extends StatelessWidget {
  const _ItineraryItemCard({required this.item});

  final GeneratedItineraryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRest = item.itemKind == ItineraryItemKind.rest;
    final arrivalText = _formatTime(item.plannedArrival);
    final departureText = _formatTime(item.plannedDeparture);

    return Card(
      child: Padding(
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
                    children: [
                      Icon(
                        isRest ? Icons.coffee_outlined : Icons.place_outlined,
                        size: 18,
                        color: isRest
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          isRest
                              ? 'Suggested break'
                              : (item.poiName ?? 'Visit'),
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRest && item.isMandatory) _MandatoryBadge(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isRest
                        ? 'Food and drinks are not included.'
                        : _subtitleText(item),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!isRest && item.estimatedCost != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Est. ${_formatVnd(item.estimatedCost!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${item.stayDurationMinutes} min',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleText(GeneratedItineraryItem item) {
    if (item.isMandatory) return 'Must-see location';
    if (item.recommendationReason != null) return item.recommendationReason!;
    return 'Suggested nearby location';
  }
}

final class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.arrival, required this.departure});

  final String arrival;
  final String departure;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return SizedBox(
      width: 44,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(arrival, style: style),
          const SizedBox(height: AppSpacing.xs),
          Text(departure, style: style),
        ],
      ),
    );
  }
}

final class _MandatoryBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: AppSpacing.xs),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      'Must-see',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    ),
  );
}
