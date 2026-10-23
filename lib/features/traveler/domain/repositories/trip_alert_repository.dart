import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/weather_advisory.dart';

abstract interface class TripAlertRepository {
  Future<List<TripAlert>> listAlerts(int sessionId);

  Future<void> acknowledgeAlert({
    required int sessionId,
    required int incidentId,
  });

  Future<List<WeatherAdvisory>> listWeatherAdvisories(int sessionId);

  Future<TripAlert> reportDeviation({
    required int sessionId,
    required String eventId,
    required DateTime observedAtUtc,
    required int targetItemId,
  });
}
