import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
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
    return Material(
      color: AppColors.primarySoft,
      child: ListTile(
        leading: const Icon(
          Icons.water_drop_outlined,
          color: AppColors.primary,
        ),
        title: Text('Rain near ${advisory.poiName}'),
        subtitle: Text(
          '${advisory.rainMmPerHour.toStringAsFixed(1)} mm/h around the planned arrival time.',
        ),
        trailing: IconButton(
          tooltip: 'Dismiss weather advisory',
          onPressed: onDismiss,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}
