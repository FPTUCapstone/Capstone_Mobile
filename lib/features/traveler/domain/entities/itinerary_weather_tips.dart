import 'package:equatable/equatable.dart';

enum WeatherTipSeverity { info, warning }

/// One thing to bring, worded by the backend. [text] is shown as given.
final class WeatherTip extends Equatable {
  const WeatherTip({
    required this.code,
    required this.severity,
    required this.text,
  });

  final String code;
  final WeatherTipSeverity severity;
  final String text;

  @override
  List<Object?> get props => [code, severity, text];
}

final class WeatherTipsSummary extends Equatable {
  const WeatherTipsSummary({
    required this.minTempC,
    required this.maxTempC,
    required this.maxRainProbabilityPercent,
    required this.maxUvIndex,
  });

  final int minTempC;
  final int maxTempC;
  final int maxRainProbabilityPercent;
  final int maxUvIndex;

  @override
  List<Object?> get props => [
    minTempC,
    maxTempC,
    maxRainProbabilityPercent,
    maxUvIndex,
  ];
}

/// UC-10: the weather tips of an itinerary day, as the backend computed them
/// from the forecast. Mobile never works out weather itself.
final class ItineraryWeatherTips extends Equatable {
  const ItineraryWeatherTips({
    required this.date,
    required this.timeZoneId,
    required this.forecastAtUtc,
    required this.summary,
    required this.tips,
  });

  /// Local date of the plan, `yyyy-MM-dd`.
  final String date;
  final String timeZoneId;
  final DateTime forecastAtUtc;
  final WeatherTipsSummary summary;
  final List<WeatherTip> tips;

  /// `2026-11-25` -> `25/11`, taken from the string so the day can never shift
  /// with the device's time zone.
  String get dayAndMonth {
    final parts = date.split('-');
    return '${parts[2]}/${parts[1]}';
  }

  @override
  List<Object?> get props => [date, timeZoneId, forecastAtUtc, summary, tips];
}
