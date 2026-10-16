import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preference_options.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preferences.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_preferences_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_state.dart';

void main() {
  group('TravelPreferencesCubit', () {
    test('load() populates options and current preferences', () async {
      final cubit = TravelPreferencesCubit(
        _FakeRepository(
          preferences: const TravelPreferences(
            interests: ['Beach'],
            preferredTransportMode: 'Car',
            travelPace: null,
            riskTolerance: null,
            foodPreferences: [],
          ),
        ),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, TravelPreferencesStatus.ready);
      expect(cubit.state.options.preferredTransportModes, ['Car', 'Motorbike']);
      expect(cubit.state.preferences.interests, ['Beach']);
      expect(cubit.state.preferences.preferredTransportMode, 'Car');
    });

    test('load() emits an error state when the repository throws', () async {
      final cubit = TravelPreferencesCubit(
        _FakeRepository(getPreferencesError: const ServerFailure()),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, TravelPreferencesStatus.error);
    });

    test('toggleInterest blocks an 11th distinct selection', () async {
      final cubit = TravelPreferencesCubit(_FakeRepository());
      addTearDown(cubit.close);
      await cubit.load();

      for (var i = 0; i < 10; i++) {
        cubit.toggleInterest('Interest$i');
      }
      cubit.toggleInterest('Interest10');

      expect(cubit.state.preferences.interests, hasLength(10));
      expect(cubit.state.fieldErrors['interests'], isNotNull);
    });

    test(
      'toggleFoodPreference(NoRestriction) clears every other food selection',
      () async {
        final cubit = TravelPreferencesCubit(_FakeRepository());
        addTearDown(cubit.close);
        await cubit.load();

        cubit.toggleFoodPreference('Vegetarian');
        cubit.toggleFoodPreference('Halal');
        cubit.toggleFoodPreference('NoRestriction');

        expect(cubit.state.preferences.foodPreferences, ['NoRestriction']);
      },
    );

    test(
      'toggleFoodPreference with a real value after NoRestriction replaces it',
      () async {
        final cubit = TravelPreferencesCubit(_FakeRepository());
        addTearDown(cubit.close);
        await cubit.load();

        cubit.toggleFoodPreference('NoRestriction');
        cubit.toggleFoodPreference('Vegetarian');

        expect(cubit.state.preferences.foodPreferences, ['Vegetarian']);
      },
    );

    test(
      'setPreferredTransportMode(null) clears a previously saved value',
      () async {
        final cubit = TravelPreferencesCubit(
          _FakeRepository(
            preferences: const TravelPreferences(
              interests: [],
              preferredTransportMode: 'Car',
              travelPace: null,
              riskTolerance: null,
              foodPreferences: [],
            ),
          ),
        );
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.preferences.preferredTransportMode, 'Car');

        cubit.setPreferredTransportMode(null);

        expect(cubit.state.preferences.preferredTransportMode, isNull);
      },
    );

    test(
      'save() sends the full state and replaces it from the response',
      () async {
        final repository = _FakeRepository();
        final cubit = TravelPreferencesCubit(repository);
        addTearDown(cubit.close);
        await cubit.load();
        cubit.setTravelPace('Relaxed');

        final result = await cubit.save();

        expect(result, isTrue);
        expect(cubit.state.status, TravelPreferencesStatus.success);
        expect(repository.updateRequest?.travelPace, 'Relaxed');
      },
    );

    test(
      'save() keeps the current selections on a field-targeted failure',
      () async {
        final cubit = TravelPreferencesCubit(
          _FakeRepository(
            updateError: const ValidationFailure(
              'No restriction cannot be combined with other food preferences.',
              fieldErrors: {
                'foodPreferences': [
                  'No restriction cannot be combined with other food preferences.',
                ],
              },
            ),
          ),
        );
        addTearDown(cubit.close);
        await cubit.load();
        cubit.toggleFoodPreference('Vegetarian');

        final result = await cubit.save();

        expect(result, isFalse);
        expect(cubit.state.fieldErrors['foodPreferences'], isNotNull);
        expect(cubit.state.preferences.foodPreferences, ['Vegetarian']);
      },
    );
  });
}

final class _FakeRepository implements TravelPreferencesRepository {
  _FakeRepository({
    this.preferences = const TravelPreferences.empty(),
    this.getPreferencesError,
    this.updateError,
  });

  final TravelPreferences preferences;
  final Object? getPreferencesError;
  final Object? updateError;
  TravelPreferences? updateRequest;

  @override
  Future<TravelPreferenceOptions> getOptions() async =>
      const TravelPreferenceOptions(
        interests: [
          InterestOption(key: 'Beach', source: 'Category'),
          InterestOption(key: 'Heritage', source: 'Category'),
        ],
        preferredTransportModes: ['Car', 'Motorbike'],
        travelPaces: ['Relaxed', 'Moderate', 'Fast'],
        foodPreferences: ['NoRestriction', 'Vegetarian', 'Halal'],
        riskTolerances: ['Low', 'Medium', 'High'],
      );

  @override
  Future<TravelPreferences> getPreferences() async {
    if (getPreferencesError != null) throw getPreferencesError!;
    return preferences;
  }

  @override
  Future<TravelPreferences> updatePreferences(
    TravelPreferences preferences,
  ) async {
    updateRequest = preferences;
    if (updateError != null) throw updateError!;
    return preferences;
  }
}
