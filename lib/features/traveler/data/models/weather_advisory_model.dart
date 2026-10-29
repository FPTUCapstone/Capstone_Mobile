import 'package:trip_mate_mobile/features/traveler/domain/entities/weather_advisory.dart';

abstract final class WeatherAdvisoryModel {
  static WeatherAdvisory fromJson(Map<String, dynamic> json) {
    if (json['severity'] != 'Info' ||
        json['messageCode'] != 'trip_alert.weather_advisory') {
      throw const FormatException('Unsupported weather advisory taxonomy.');
    }

    DateTime date(String key) {
      final value = DateTime.tryParse(json[key] as String? ?? '');
      if (value == null || !value.isUtc) {
        throw FormatException('$key must be UTC.');
      }
      return value;
    }

    int integer(String key) {
      final value = json[key];
      if (value is num) return value.toInt();
      throw FormatException('Missing $key.');
    }

    return WeatherAdvisory(
      advisoryKey: _requiredString(json, 'advisoryKey'),
      messageCode: 'trip_alert.weather_advisory',
      itemId: integer('itemId'),
      poiId: integer('poiId'),
      poiName: _requiredString(json, 'poiName'),
      plannedArrivalUtc: date('plannedArrivalUtc'),
      forecastAtUtc: date('forecastAtUtc'),
      rainMmPerHour: _rainIntensity(json['rainIntensityMmPerHour']),
      condition: json['condition'] as String?,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('Missing $key.');
  }

  static double _rainIntensity(Object? value) {
    if (value is num && value.isFinite && value >= 0) return value.toDouble();
    throw const FormatException('Invalid rainIntensityMmPerHour.');
  }
}
