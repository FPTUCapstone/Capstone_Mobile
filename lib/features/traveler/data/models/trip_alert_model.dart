import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';

abstract final class TripAlertModel {
  static TripAlert fromJson(Map<String, dynamic> json) {
    final affected = json['affectedItem'];
    final affectedItem = affected is Map<String, dynamic> ? affected : null;
    final type = _type(json['type']);
    final messageCode = _string(json, 'messageCode');
    final name = affectedItem?['name'] as String? ?? '';
    return TripAlert(
      id: _integer(json, 'incidentId').toString(),
      title: _title(messageCode),
      description: _description(messageCode, name),
      severity: _severity(json['severity']),
      type: type,
      affectedStopName: name,
      timestamp: _date(json, 'detectedAtUtc'),
      messageCode: messageCode,
      affectedItemId: _optionalInteger(affectedItem?['itemId']),
      resolvedAt: _optionalDate(json['resolvedAtUtc']),
      isRead: json['isRead'] == true,
      reroutingProposalId: _optionalInteger(json['reroutingProposalId']),
    );
  }

  static TripAlertType _type(Object? value) => switch (value) {
    'SevereWeather' => TripAlertType.weather,
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
    'trip_alert.severe_weather' => 'Severe weather',
    'trip_alert.schedule_delay' => 'Schedule update',
    'trip_alert.route_deviation' => 'Route deviation',
    'trip_alert.poi_closure' => 'Place unavailable',
    _ => throw FormatException('Unsupported trip alert message code: $code'),
  };

  static String _description(String code, String name) => switch (code) {
    'trip_alert.severe_weather' => 'Severe weather may affect your trip.',
    'trip_alert.schedule_delay' =>
      '${name.isEmpty ? 'This stop' : name} has not been recorded as reached on time.',
    'trip_alert.route_deviation' =>
      'You appear to be away from the planned route.',
    'trip_alert.poi_closure' =>
      '${name.isEmpty ? 'This place' : name} is currently unavailable.',
    _ => '',
  };

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
}
