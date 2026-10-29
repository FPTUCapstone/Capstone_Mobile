import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/trip_alert_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/weather_advisory_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';

void main() {
  test('maps the frozen Backend alert contract', () {
    final alert = TripAlertModel.fromJson({
      'incidentId': 42,
      'type': 'ScheduleDelay',
      'severity': 'Warning',
      'messageCode': 'trip_alert.schedule_delay',
      'description': null,
      'affectedItem': {
        'itemId': 7,
        'poiId': 11,
        'name': 'Museum',
        'plannedArrivalUtc': '2026-10-23T02:00:00Z',
      },
      'detectedAtUtc': '2026-10-23T02:31:00Z',
      'resolvedAtUtc': '2026-10-23T02:45:00Z',
      'isRead': true,
      'reroutingProposalId': 99,
    });

    expect(alert.id, '42');
    expect(alert.type, TripAlertType.delay);
    expect(alert.severity, AlertSeverity.warning);
    expect(alert.messageCode, 'trip_alert.schedule_delay');
    expect(alert.affectedItemId, 7);
    expect(alert.affectedStopName, 'Museum');
    expect(alert.isRead, isTrue);
    expect(alert.isResolved, isTrue);
    expect(alert.reroutingProposalId, 99);
  });

  test('rejects unknown alert taxonomy instead of showing wrong copy', () {
    expect(
      () => TripAlertModel.fromJson({
        'incidentId': 1,
        'type': 'Unknown',
        'severity': 'Warning',
        'messageCode': 'trip_alert.unknown',
        'detectedAtUtc': '2026-10-23T02:31:00Z',
        'isRead': false,
      }),
      throwsFormatException,
    );
  });

  test('maps a persisted rain preparation alert with forecast evidence', () {
    final alert = TripAlertModel.fromJson({
      'incidentId': 51,
      'type': 'WeatherAdvisory',
      'severity': 'Info',
      'messageCode': 'trip_alert.weather_advisory',
      'affectedItem': {
        'itemId': 7,
        'poiId': 11,
        'name': 'Marble Mountains',
        'plannedArrivalUtc': '2026-10-28T09:00:00Z',
      },
      'weatherBasis': 'ForecastAtPlannedTime',
      'weatherAtUtc': '2026-10-28T09:00:00Z',
      'rainIntensityMmPerHour': 4.5,
      'detectedAtUtc': '2026-10-28T08:20:00Z',
      'isRead': false,
    });

    expect(alert.type, TripAlertType.weather);
    expect(alert.severity, AlertSeverity.info);
    expect(alert.weatherBasis, WeatherBasis.forecastAtPlannedTime);
    expect(alert.weatherAtUtc, DateTime.utc(2026, 10, 28, 9));
    expect(alert.rainIntensityMmPerHour, 4.5);
    expect(alert.description, contains('Marble Mountains'));
    expect(alert.description, contains('forecast'));
    expect(alert.description, contains('Weather data at'));
  });

  test(
    'distinguishes current destination weather from an arrival forecast',
    () {
      final alert = TripAlertModel.fromJson({
        'incidentId': 52,
        'type': 'SevereWeather',
        'severity': 'Warning',
        'messageCode': 'trip_alert.severe_weather',
        'affectedItem': {
          'itemId': 8,
          'poiId': 12,
          'name': 'My Khe Beach',
          'plannedArrivalUtc': '2026-10-28T08:00:00Z',
        },
        'weatherBasis': 'CurrentAtDestination',
        'weatherAtUtc': '2026-10-28T09:00:00Z',
        'rainIntensityMmPerHour': 12.3,
        'canSkipAffectedStop': true,
        'weatherCondition': 'Thunderstorm',
        'detectedAtUtc': '2026-10-28T09:02:00Z',
        'isRead': false,
      });

      expect(alert.weatherBasis, WeatherBasis.currentAtDestination);
      expect(alert.canSkipAffectedStop, isTrue);
      expect(alert.description, contains('currently at My Khe Beach'));
      expect(alert.description, contains('thunderstorm'));
      expect(alert.description, isNot(contains('Heavy rain')));
      expect(alert.description, contains('Weather data at'));
      expect(alert.description, isNot(contains('when you arrive')));
      expect(alert.description, contains('postponing or skipping'));
    },
  );

  test('maps a transient weather advisory separately', () {
    final advisory = WeatherAdvisoryModel.fromJson({
      'advisoryKey': 'rain:7:20261023T0200Z',
      'severity': 'Info',
      'messageCode': 'trip_alert.weather_advisory',
      'itemId': 7,
      'poiId': 11,
      'poiName': 'Museum',
      'plannedArrivalUtc': '2026-10-23T02:00:00Z',
      'forecastAtUtc': '2026-10-23T02:15:00Z',
      'rainIntensityMmPerHour': 4.5,
      'condition': 'moderate rain',
    });

    expect(advisory.advisoryKey, 'rain:7:20261023T0200Z');
    expect(advisory.rainMmPerHour, 4.5);
    expect(advisory.poiName, 'Museum');
  });

  test('rejects an advisory outside the frozen taxonomy', () {
    expect(
      () => WeatherAdvisoryModel.fromJson({
        'advisoryKey': 'rain:7',
        'severity': 'Warning',
        'messageCode': 'trip_alert.unknown',
        'itemId': 7,
        'poiId': 11,
        'poiName': 'Museum',
        'plannedArrivalUtc': '2026-10-23T02:00:00Z',
        'forecastAtUtc': '2026-10-23T02:15:00Z',
        'rainMmPerHour': 4.5,
      }),
      throwsFormatException,
    );
  });
}
