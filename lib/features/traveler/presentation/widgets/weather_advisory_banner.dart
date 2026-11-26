import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/weather_advisory.dart';

class WeatherAdvisoryBanner extends StatelessWidget {
  const WeatherAdvisoryBanner({
    super.key,
    required this.advisory,
    required this.onDismiss,
  });

  final WeatherAdvisory advisory;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: palette.softAccent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.ink.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.water_drop_outlined,
              color: palette.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mưa gần ${advisory.poiName}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: palette.ink,
                  ),
                ),
                Text(
                  'Dự báo ${advisory.rainMmPerHour.toStringAsFixed(1)} mm/h vào giờ dự kiến đến.',
                  style: TextStyle(fontSize: 12, color: palette.secondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đóng thông báo thời tiết',
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, size: 18, color: palette.ink),
          ),
        ],
      ),
    );
  }
}
