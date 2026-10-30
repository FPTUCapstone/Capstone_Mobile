import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';

abstract final class TripAlertModel {
  static TripAlert fromJson(Map<String, dynamic> json) {
    final affected = json['affectedItem'];
    final affectedItem = affected is Map<String, dynamic> ? affected : null;
    final type = _type(json['type']);
    final messageCode = _string(json, 'messageCode');
    final name = affectedItem?['name'] as String? ?? '';
    final weatherBasis = _weatherBasis(json['weatherBasis']);
    final rainIntensity = _rainIntensity(json['rainIntensityMmPerHour']);
    final weatherCondition = _weatherCondition(json['weatherCondition']);
    final weatherAtUtc = _optionalUtcDate(json['weatherAtUtc']);
    return TripAlert(
      id: _integer(json, 'incidentId').toString(),
      title: _title(messageCode),
      description: _description(
        messageCode,
        name,
        weatherBasis,
        rainIntensity,
        weatherAtUtc,
        weatherCondition,
      ),
      severity: _severity(json['severity']),
      type: type,
      affectedStopName: name,
      timestamp: _date(json, 'detectedAtUtc'),
      messageCode: messageCode,
      affectedItemId: _optionalInteger(affectedItem?['itemId']),
      resolvedAt: _optionalDate(json['resolvedAtUtc']),
      isRead: json['isRead'] == true,
      reroutingProposalId: _optionalInteger(json['reroutingProposalId']),
      weatherBasis: weatherBasis,
      weatherAtUtc: weatherAtUtc,
      rainIntensityMmPerHour: rainIntensity,
      canSkipAffectedStop: json['canSkipAffectedStop'] == true,
    );
  }

  static TripAlertType _type(Object? value) => switch (value) {
    'SevereWeather' || 'WeatherAdvisory' => TripAlertType.weather,
    'ScheduleDelay' => TripAlertType.delay,
    'RouteDeviation' => TripAlertType.deviation,
    'POIClosure' => TripAlertType.closure,
    _ => throw FormatException('Unsupported trip alert type: $value'),
  };

  static AlertSeverity _severity(Object? value) => switch (value) {
    'Info' => AlertSeverity.info,
    'Warning' => AlertSeverity.warning,
    'Critical' || 'Severe' => AlertSeverity.critical,
    _ => throw FormatException('Unsupported trip alert severity: $value'),
  };

  static String _title(String code) => switch (code) {
    'trip_alert.weather_advisory' => 'Rain preparation',
    'trip_alert.severe_weather' => 'Severe weather',
    'trip_alert.schedule_delay' => 'Schedule update',
    'trip_alert.route_deviation' => 'Route deviation',
    'trip_alert.poi_closure' => 'Place unavailable',
    _ => throw FormatException('Unsupported trip alert message code: $code'),
  };

  static String _description(
    String code,
    String name,
    WeatherBasis? basis,
    double? rainIntensity,
    DateTime? weatherAtUtc,
    String? weatherCondition,
  ) => switch (code) {
    'trip_alert.weather_advisory' =>
      'Rain is forecast at ${name.isEmpty ? 'this stop' : name} around your planned visit. Prepare for wet weather.${_weatherTime(weatherAtUtc)}',
    'trip_alert.severe_weather' => _weatherDescription(
      name,
      basis,
      rainIntensity,
      weatherAtUtc,
      weatherCondition,
    ),
    'trip_alert.schedule_delay' =>
      '${name.isEmpty ? 'This stop' : name} has not been recorded as reached on time.',
    'trip_alert.route_deviation' =>
      'You appear to be away from the planned route.',
    'trip_alert.poi_closure' =>
      '${name.isEmpty ? 'This place' : name} is currently unavailable.',
    _ => '',
  };

  static String _weatherDescription(
    String name,
    WeatherBasis? basis,
    double? rainIntensity,
    DateTime? weatherAtUtc,
    String? weatherCondition,
  ) {
    final place = name.isEmpty ? 'the destination' : name;
    final condition = switch (weatherCondition) {
      'Thunderstorm' => 'A thunderstorm',
      'ExtremeRain' =>
        rainIntensity == null
            ? 'Extreme rain'
            : 'Extreme rain (${rainIntensity.toStringAsFixed(1)} mm/h)',
      'HeavyRain' =>
        rainIntensity == null
            ? 'Heavy rain'
            : 'Heavy rain (${rainIntensity.toStringAsFixed(1)} mm/h)',
      _ =>
        rainIntensity == null
            ? 'Severe weather'
            : 'Weather warning (${rainIntensity.toStringAsFixed(1)} mm/h rain)',
    };
    final description = switch (basis) {
      WeatherBasis.currentAtDestination =>
        '$condition is currently at $place. Consider postponing or skipping the affected stop.',
      WeatherBasis.forecastAtPlannedTime =>
        '$condition is forecast at $place for the planned visit time. Consider postponing or skipping the affected stop.',
      WeatherBasis.officialEvent =>
        'An official weather warning affects $place. Check the source alert before visiting.',
      null => '$condition may affect $place. Check this stop before visiting.',
    };
    return '$description${_weatherTime(weatherAtUtc)}';
  }

  static String _weatherTime(DateTime? utc) {
    if (utc == null) return '';
    final local = utc.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return ' Weather data at $hour:$minute on ${local.day}/${local.month} (device time).';
  }

  static WeatherBasis? _weatherBasis(Object? value) => switch (value) {
    null => null,
    'ForecastAtPlannedTime' => WeatherBasis.forecastAtPlannedTime,
    'CurrentAtDestination' => WeatherBasis.currentAtDestination,
    'OfficialEvent' => WeatherBasis.officialEvent,
    _ => throw FormatException('Unsupported weather basis: $value'),
  };

  static String? _weatherCondition(Object? value) => switch (value) {
    null => null,
    'ModerateRain' ||
    'HeavyRain' ||
    'ExtremeRain' ||
    'Thunderstorm' => value as String,
    _ => throw FormatException('Unsupported weather condition: $value'),
  };

  static double? _rainIntensity(Object? value) {
    if (value == null) return null;
    if (value is! num || !value.isFinite || value < 0) {
      throw const FormatException('Invalid rainIntensityMmPerHour.');
    }
    return value.toDouble();
  }

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('Missing $key.');
  }

  static int _integer(Map<String, dynamic> json, String key) {
    final value = _optionalInteger(json[key]);
    if (value != null) return value;
    throw FormatException('Missing $key.');
  }

  static int? _optionalInteger(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };

  static DateTime _date(Map<String, dynamic> json, String key) {
    final value = _optionalDate(json[key]);
    if (value != null && value.isUtc) return value;
    throw FormatException('$key must be UTC.');
  }

  static DateTime? _optionalDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static DateTime? _optionalUtcDate(Object? value) {
    final date = _optionalDate(value);
    if (date != null && !date.isUtc) {
      throw const FormatException('weatherAtUtc must be UTC.');
    }
    return date;
  }
}
