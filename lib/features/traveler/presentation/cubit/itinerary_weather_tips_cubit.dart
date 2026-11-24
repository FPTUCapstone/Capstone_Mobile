import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_weather_tips_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_weather_tips_state.dart';

/// UC-10: asks once per itinerary for the weather tips of its day. Anything
/// but tips (no repository, "not available", an error) leaves the state empty,
/// which hides the card (specs/UC-10-weather-packing-tips-mobile-spec.md, M1-M3).
final class ItineraryWeatherTipsCubit extends Cubit<ItineraryWeatherTipsState> {
  ItineraryWeatherTipsCubit({
    required ItineraryWeatherTipsRepository? repository,
  }) : _repository = repository,
       super(const ItineraryWeatherTipsState());

  final ItineraryWeatherTipsRepository? _repository;
  int? _requestedId;

  /// Does nothing for an id that was already requested, so reloading the
  /// itinerary after an edit, an undo or an explanation refresh costs nothing.
  Future<void> load(int itineraryId) async {
    final repository = _repository;
    if (repository == null || _requestedId == itineraryId) return;
    _requestedId = itineraryId;
    if (state.tips != null) emit(const ItineraryWeatherTipsState());

    ItineraryWeatherTips? tips;
    try {
      tips = await repository.getWeatherTips(itineraryId);
    } catch (_) {
      tips = null;
    }
    if (isClosed || _requestedId != itineraryId || tips == null) return;
    emit(ItineraryWeatherTipsState(tips: tips));
  }
}
