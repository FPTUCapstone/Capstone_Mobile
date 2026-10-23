import 'package:equatable/equatable.dart';

final class WeatherAdvisory extends Equatable {
  const WeatherAdvisory({
    required this.advisoryKey,
    required this.messageCode,
    required this.itemId,
    required this.poiId,
    required this.poiName,
    required this.plannedArrivalUtc,
    required this.forecastAtUtc,
    required this.rainMmPerHour,
    this.condition,
  });

  final String advisoryKey;
  final String messageCode;
  final int itemId;
  final int poiId;
  final String poiName;
  final DateTime plannedArrivalUtc;
  final DateTime forecastAtUtc;
  final double rainMmPerHour;
  final String? condition;

  @override
  List<Object?> get props => [
    advisoryKey,
    messageCode,
    itemId,
    poiId,
    poiName,
    plannedArrivalUtc,
    forecastAtUtc,
    rainMmPerHour,
    condition,
  ];
}
