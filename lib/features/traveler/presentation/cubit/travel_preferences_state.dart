import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preference_options.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preferences.dart';

enum TravelPreferencesStatus { loading, ready, saving, success, error }

final class TravelPreferencesState extends Equatable {
  const TravelPreferencesState({
    this.status = TravelPreferencesStatus.loading,
    this.options = const TravelPreferenceOptions.empty(),
    this.preferences = const TravelPreferences.empty(),
    this.errorMessage,
    this.fieldErrors = const <String, List<String>>{},
    this.requiresSignIn = false,
  });

  final TravelPreferencesStatus status;
  final TravelPreferenceOptions options;
  final TravelPreferences preferences;
  final String? errorMessage;
  final Map<String, List<String>> fieldErrors;

  /// Signals that the API rejected the current credentials. The page owns the
  /// auth side effect so this feature cubit stays independent from auth.
  final bool requiresSignIn;

  bool get isLoading => status == TravelPreferencesStatus.loading;
  bool get isSaving => status == TravelPreferencesStatus.saving;

  @override
  List<Object?> get props => [
    status,
    options,
    preferences,
    errorMessage,
    fieldErrors,
    requiresSignIn,
  ];
}
