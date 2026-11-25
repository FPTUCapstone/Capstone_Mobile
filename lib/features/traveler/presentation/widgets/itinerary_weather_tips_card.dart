import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';

/// UC-10: what to bring because of the weather that day. It shows only what the
/// backend sent, in the order it sent it, and never works out weather itself
/// (specs/UC-10-weather-packing-tips-mobile-spec.md).
final class ItineraryWeatherTipsCard extends StatelessWidget {
  const ItineraryWeatherTipsCard({required this.tips, super.key});

  final ItineraryWeatherTips tips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = tips.summary;
    return Semantics(
      container: true,
      label: 'Gợi ý theo thời tiết',
      child: Card(
        key: const Key('itinerary_weather_tips_card'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.wb_sunny_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Thời tiết ngày ${tips.dayAndMonth}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${summary.minTempC}–${summary.maxTempC}°C · '
                'Mưa tối đa ${summary.maxRainProbabilityPercent}% · '
                'UV ${summary.maxUvIndex}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (tips.tips.isEmpty)
                Text(
                  'Thời tiết thuận lợi, không cần chuẩn bị đặc biệt.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                for (final tip in tips.tips) _TipRow(tip: tip),
            ],
          ),
        ),
      ),
    );
  }
}

final class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip});

  final WeatherTip tip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tip.severity == WeatherTipSeverity.warning) {
      final colors = context.tmColors;
      return Container(
        key: const Key('weather_tip_warning'),
        margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: colors.warningContainer,
          border: Border.all(color: colors.warning),
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: colors.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(tip.text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(child: Text('•')),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(tip.text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
