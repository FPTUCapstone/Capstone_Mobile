import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preferences.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_preferences_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_state.dart';

/// UC-09: loads the Traveler's real options catalogue and saved preferences
/// from the Backend, and saves the full five-field state. Replaces the
/// previous in-memory demo (`.defaults()`/`reset()`/`autoApply`), which had
/// no Backend integration at all.
final class TravelPreferencesCubit extends Cubit<TravelPreferencesState> {
  TravelPreferencesCubit(this._repository)
    : super(const TravelPreferencesState());

  static const noRestriction = 'NoRestriction';

  /// Mirrors `TravelerPreferenceKeys.MaxInterests` on the Backend; enforced
  /// here only for early feedback — the Backend remains authoritative.
  static const maxInterests = 10;

  final TravelPreferencesRepository _repository;

  Future<void> load() async {
    emit(const TravelPreferencesState());
    try {
      final options = await _repository.getOptions();
      final preferences = await _repository.getPreferences();
      if (isClosed) return;
      emit(
        TravelPreferencesState(
          status: TravelPreferencesStatus.ready,
          options: options,
          preferences: preferences,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        TravelPreferencesState(
          status: TravelPreferencesStatus.error,
          errorMessage: _messageOf(error),
        ),
      );
    }
  }

  void toggleInterest(String key) {
    if (state.isSaving) return;
    final interests = Set<String>.of(state.preferences.interests);
    if (!interests.remove(key)) {
      if (interests.length >= maxInterests) {
        _emitFieldError('interests', 'You can select up to 10 interests.');
        return;
      }
      interests.add(key);
    }
    _applyPreferences(_withInterests(interests));
  }

  void toggleFoodPreference(String key) {
    if (state.isSaving) return;
    final current = Set<String>.of(state.preferences.foodPreferences);
    if (current.remove(key)) {
      _applyPreferences(_withFood(current));
      return;
    }
    if (key == noRestriction) {
      current.clear();
    } else {
      current.remove(noRestriction);
    }
    current.add(key);
    _applyPreferences(_withFood(current));
  }

  void setPreferredTransportMode(String? value) =>
      _applyPreferences(_withTransport(value));

  void setTravelPace(String? value) => _applyPreferences(_withPace(value));

  void setRiskTolerance(String? value) => _applyPreferences(_withRisk(value));

  Future<bool> save() async {
    if (isClosed || state.isSaving) return false;

    emit(
      TravelPreferencesState(
        status: TravelPreferencesStatus.saving,
        options: state.options,
        preferences: state.preferences,
      ),
    );

    try {
      final saved = await _repository.updatePreferences(state.preferences);
      if (isClosed) return false;
      emit(
        TravelPreferencesState(
          status: TravelPreferencesStatus.success,
          options: state.options,
          preferences: saved,
        ),
      );
      return true;
    } on Failure catch (failure) {
      if (isClosed) return false;
      final fieldErrors = failure is ValidationFailure
          ? failure.fieldErrors
          : const <String, List<String>>{};
      emit(
        TravelPreferencesState(
          status: TravelPreferencesStatus.ready,
          options: state.options,
          preferences: state.preferences,
          errorMessage: fieldErrors.isEmpty ? failure.message : null,
          fieldErrors: fieldErrors,
        ),
      );
      return false;
    } catch (_) {
      if (isClosed) return false;
      emit(
        TravelPreferencesState(
          status: TravelPreferencesStatus.ready,
          options: state.options,
          preferences: state.preferences,
          errorMessage: 'Something went wrong. Please try again later.',
        ),
      );
      return false;
    }
  }

  void _emitFieldError(String field, String message) {
    emit(
      TravelPreferencesState(
        status: state.status,
        options: state.options,
        preferences: state.preferences,
        fieldErrors: {
          ...state.fieldErrors,
          field: [message],
        },
      ),
    );
  }

  void _applyPreferences(TravelPreferences preferences) {
    emit(
      TravelPreferencesState(
        status: state.status,
        options: state.options,
        preferences: preferences,
      ),
    );
  }

  TravelPreferences _withInterests(Set<String> interests) => TravelPreferences(
    interests: interests.toList(growable: false),
    preferredTransportMode: state.preferences.preferredTransportMode,
    travelPace: state.preferences.travelPace,
    riskTolerance: state.preferences.riskTolerance,
    foodPreferences: state.preferences.foodPreferences,
  );

  TravelPreferences _withFood(Set<String> food) => TravelPreferences(
    interests: state.preferences.interests,
    preferredTransportMode: state.preferences.preferredTransportMode,
    travelPace: state.preferences.travelPace,
    riskTolerance: state.preferences.riskTolerance,
    foodPreferences: food.toList(growable: false),
  );

  TravelPreferences _withTransport(String? value) => TravelPreferences(
    interests: state.preferences.interests,
    preferredTransportMode: value,
    travelPace: state.preferences.travelPace,
    riskTolerance: state.preferences.riskTolerance,
    foodPreferences: state.preferences.foodPreferences,
  );

  TravelPreferences _withPace(String? value) => TravelPreferences(
    interests: state.preferences.interests,
    preferredTransportMode: state.preferences.preferredTransportMode,
    travelPace: value,
    riskTolerance: state.preferences.riskTolerance,
    foodPreferences: state.preferences.foodPreferences,
  );

  TravelPreferences _withRisk(String? value) => TravelPreferences(
    interests: state.preferences.interests,
    preferredTransportMode: state.preferences.preferredTransportMode,
    travelPace: state.preferences.travelPace,
    riskTolerance: value,
    foodPreferences: state.preferences.foodPreferences,
  );

  String _messageOf(Object error) => error is Failure
      ? error.message
      : 'Something went wrong. Please try again later.';
}
