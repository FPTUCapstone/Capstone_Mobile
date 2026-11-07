import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/data/realtime/signalr_operator_weather_safety_realtime.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_realtime.dart';

void main() {
  test('reads the Backend WeatherSafetyReviewChanged payload', () {
    final hint = SignalROperatorWeatherSafetyRealtime.parseHint([
      {
        'reviewId': 7,
        'tourScheduleId': 31,
        'changeType': 'Escalated',
        'occurredAtUtc': '2026-11-09T09:00:00Z',
      },
    ]);

    expect(
      hint,
      WeatherSafetyReviewHint(
        reviewId: 7,
        changeType: 'Escalated',
        occurredAtUtc: DateTime.utc(2026, 11, 9, 9),
      ),
    );
  });

  test('anything unexpected is ignored rather than trusted', () {
    final hints = [
      null,
      <Object?>[],
      <Object?>['text'],
      [
        {'reviewId': 'x', 'changeType': 'Created'},
      ],
      [
        {'reviewId': 7, 'occurredAtUtc': '2026-11-09T09:00:00Z'},
      ],
      [
        {'reviewId': 7, 'changeType': 'Created', 'occurredAtUtc': 'not-a-date'},
      ],
    ].map(SignalROperatorWeatherSafetyRealtime.parseHint);

    expect(hints, everyElement(isNull));
  });

  test('the hub url is built from the configured API origin', () {
    expect(
      SignalROperatorWeatherSafetyRealtime.hubUrl(
        Uri.parse('https://api.test.invalid/'),
      ),
      'https://api.test.invalid/hubs/operator-weather-safety',
    );
    expect(
      SignalROperatorWeatherSafetyRealtime.hubUrl(
        Uri.parse('http://10.0.2.2:5000'),
      ),
      'http://10.0.2.2:5000/hubs/operator-weather-safety',
    );
  });
}
