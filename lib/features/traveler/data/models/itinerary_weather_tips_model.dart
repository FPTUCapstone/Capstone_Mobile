import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';

/// Reads `{ "weatherTips": ... }` from `GET /api/v1/itineraries/{id}/weather-tips`.
abstract final class ItineraryWeatherTipsModel {
  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// The tips, or `null` when the backend has none (`weatherTips: null`) or the
  /// body is not a complete, correctly typed forecast. A half-valid body never
  /// gives a half card.
  static ItineraryWeatherTips? tryParse(Object? body) {
    if (body is! Map) return null;
    final tips = body['weatherTips'];
    if (tips is! Map) return null;

    final date = tips['date'];
    final timeZoneId = tips['timeZoneId'];
    final forecastAt = tips['forecastAtUtc'];
    final summary = _summary(tips['summary']);
    final list = tips['tips'];
    if (date is! String ||
        !_date.hasMatch(date) ||
        timeZoneId is! String ||
        forecastAt is! String ||
        summary == null ||
        list is! List) {
      return null;
    }
    final forecastAtUtc = DateTime.tryParse(forecastAt)?.toUtc();
    if (forecastAtUtc == null) return null;

    final parsedTips = <WeatherTip>[];
    for (final value in list) {
      final tip = _tip(value);
      if (tip == null) return null;
      parsedTips.add(tip);
    }
    return ItineraryWeatherTips(
      date: date,
      timeZoneId: timeZoneId,
      forecastAtUtc: forecastAtUtc,
      summary: summary,
      tips: List.unmodifiable(parsedTips),
    );
  }

  static WeatherTipsSummary? _summary(Object? value) {
    if (value is! Map) return null;
    final minTempC = _wholeNumber(value['minTempC']);
    final maxTempC = _wholeNumber(value['maxTempC']);
    final rain = _wholeNumber(value['maxRainProbabilityPercent']);
    final uv = _wholeNumber(value['maxUvIndex']);
    if (minTempC == null || maxTempC == null || rain == null || uv == null) {
      return null;
    }
    return WeatherTipsSummary(
      minTempC: minTempC,
      maxTempC: maxTempC,
      maxRainProbabilityPercent: rain,
      maxUvIndex: uv,
    );
  }

  static WeatherTip? _tip(Object? value) {
    if (value is! Map) return null;
    final code = value['code'];
    final text = value['text'];
    final severity = switch (value['severity']) {
      'Info' => WeatherTipSeverity.info,
      'Warning' => WeatherTipSeverity.warning,
      _ => null,
    };
    if (code is! String || text is! String || severity == null) return null;
    return WeatherTip(code: code, severity: severity, text: text);
  }

  /// An `int`, or a `double` that is a whole number (JSON `22.0`).
  static int? _wholeNumber(Object? value) {
    if (value is int) return value;
    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt();
    }
    return null;
  }
}
