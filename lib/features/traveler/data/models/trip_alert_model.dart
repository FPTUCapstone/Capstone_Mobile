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
    final plannedDeparture = _optionalUtcDate(
      affectedItem?['plannedDepartureUtc'],
    );
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
        plannedDeparture,
      ),
      severity: _severity(json['severity']),
      type: type,
      affectedStopName: name,
      timestamp: _date(json, 'detectedAtUtc'),
      messageCode: messageCode,
      affectedItemId: _optionalInteger(affectedItem?['itemId']),
      plannedDeparture: plannedDeparture,
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
    'trip_alert.weather_advisory' => 'Chuẩn bị ứng phó mưa',
    'trip_alert.severe_weather' => 'Thời tiết xấu',
    'trip_alert.schedule_delay' => 'Cập nhật lịch trình',
    TripAlert.stopOverstayMessageCode => 'Quá thời gian dừng chân',
    'trip_alert.route_deviation' => 'Lệch tuyến đường',
    'trip_alert.poi_closure' => 'Điểm đến tạm đóng cửa',
    _ => throw FormatException('Unsupported trip alert message code: $code'),
  };

  static String overstayDescription(String name, DateTime? plannedDeparture) {
    final place = name.isEmpty ? 'điểm dừng này' : name;
    if (plannedDeparture == null) {
      return 'Bạn đã dừng quá thời gian dự kiến tại $place.';
    }
    final local = plannedDeparture.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Bạn đã dừng quá giờ rời đi dự kiến ($hour:$minute) tại $place.';
  }

  static String _description(
    String code,
    String name,
    WeatherBasis? basis,
    double? rainIntensity,
    DateTime? weatherAtUtc,
    String? weatherCondition,
    DateTime? plannedDeparture,
  ) => switch (code) {
    'trip_alert.weather_advisory' =>
      'Dự báo có mưa tại ${name.isEmpty ? 'điểm dừng này' : name} vào khoảng thời gian bạn dự kiến ghé thăm. Hãy chuẩn bị đồ đi mưa.${_weatherTime(weatherAtUtc)}',
    'trip_alert.severe_weather' => _weatherDescription(
      name,
      basis,
      rainIntensity,
      weatherAtUtc,
      weatherCondition,
    ),
    'trip_alert.schedule_delay' =>
      '${name.isEmpty ? 'Điểm dừng này' : name} chưa được ghi nhận đã đến đúng giờ.',
    TripAlert.stopOverstayMessageCode => overstayDescription(
      name,
      plannedDeparture,
    ),
    'trip_alert.route_deviation' =>
      'Bạn có vẻ đang đi lệch khỏi lộ trình đã lên kế hoạch.',
    'trip_alert.poi_closure' =>
      '${name.isEmpty ? 'Địa điểm này' : name} hiện đang tạm đóng cửa hoặc không khả dụng.',
    _ => '',
  };

  static String _weatherDescription(
    String name,
    WeatherBasis? basis,
    double? rainIntensity,
    DateTime? weatherAtUtc,
    String? weatherCondition,
  ) {
    final place = name.isEmpty ? 'điểm đến' : name;
    final condition = switch (weatherCondition) {
      'Thunderstorm' => 'Dông bão',
      'ExtremeRain' =>
        rainIntensity == null
            ? 'Mưa rất to'
            : 'Mưa rất to (${rainIntensity.toStringAsFixed(1)} mm/h)',
      'HeavyRain' =>
        rainIntensity == null
            ? 'Mưa to'
            : 'Mưa to (${rainIntensity.toStringAsFixed(1)} mm/h)',
      _ =>
        rainIntensity == null
            ? 'Thời tiết xấu'
            : 'Cảnh báo thời tiết (mưa ${rainIntensity.toStringAsFixed(1)} mm/h)',
    };
    final description = switch (basis) {
      WeatherBasis.currentAtDestination =>
        '$condition đang xảy ra tại $place. Hãy cân nhắc hoãn hoặc bỏ qua điểm dừng bị ảnh hưởng.',
      WeatherBasis.forecastAtPlannedTime =>
        '$condition được dự báo tại $place vào thời gian tham quan dự kiến. Hãy cân nhắc hoãn hoặc bỏ qua điểm dừng bị ảnh hưởng.',
      WeatherBasis.officialEvent =>
        'Có cảnh báo thời tiết chính thức ảnh hưởng đến $place. Hãy kiểm tra thông tin cảnh báo trước khi ghé thăm.',
      null =>
        '$condition có thể ảnh hưởng đến $place. Hãy kiểm tra điểm dừng này trước khi ghé thăm.',
    };
    return '$description${_weatherTime(weatherAtUtc)}';
  }

  static String _weatherTime(DateTime? utc) {
    if (utc == null) return '';
    final local = utc.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return ' Dữ liệu thời tiết lúc $hour:$minute ngày ${local.day}/${local.month} (giờ thiết bị).';
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
