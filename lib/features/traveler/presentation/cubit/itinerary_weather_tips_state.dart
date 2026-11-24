import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';

/// [tips] is `null` until the backend has answered with tips; nothing else
/// (loading, failure, "not available") is shown, so there is no other state.
final class ItineraryWeatherTipsState extends Equatable {
  const ItineraryWeatherTipsState({this.tips});

  final ItineraryWeatherTips? tips;

  @override
  List<Object?> get props => [tips];
}
