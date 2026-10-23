import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/travel_preferences_remote_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_preference_options_dto.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_preferences_dto.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/update_travel_preferences_request.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/travel_preferences_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preferences.dart';

void main() {
  group('TravelPreferencesRepositoryImpl', () {
    test('getOptions maps the DTO to domain entities', () async {
      final remote = _FakeRemoteDataSource(
        optionsResponse: const TravelPreferenceOptionsDto(
          interests: [InterestOptionDto(key: 'Beach', source: 'Category')],
          preferredTransportModes: ['Car'],
          travelPaces: ['Relaxed'],
          foodPreferences: ['NoRestriction'],
          riskTolerances: ['Low'],
        ),
      );
      final repository = TravelPreferencesRepositoryImpl(remote);

      final options = await repository.getOptions();

      expect(options.interests.single.key, 'Beach');
      expect(options.preferredTransportModes, ['Car']);
    });

    test('updatePreferences sends the full five-field request', () async {
      final remote = _FakeRemoteDataSource(
        preferencesResponse: const TravelPreferencesDto(
          interests: ['Beach'],
          preferredTransportMode: 'Car',
          travelPace: null,
          riskTolerance: null,
          foodPreferences: [],
          updatedAtUtc: null,
        ),
      );
      final repository = TravelPreferencesRepositoryImpl(remote);

      final saved = await repository.updatePreferences(
        const TravelPreferences(
          interests: ['Beach'],
          preferredTransportMode: 'Car',
          travelPace: null,
          riskTolerance: null,
          foodPreferences: [],
        ),
      );

      expect(remote.updateRequest?.toJson(), {
        'interests': ['Beach'],
        'preferredTransportMode': 'Car',
        'travelPace': null,
        'riskTolerance': null,
        'foodPreferences': [],
      });
      expect(saved.preferredTransportMode, 'Car');
    });

    test(
      'maps TOO_MANY_INTERESTS to an interests-field ValidationFailure',
      () async {
        final remote = _FakeRemoteDataSource(
          updateError: _dioError(400, const {
            'errorCode': 'TRAVEL_PREFERENCES.TOO_MANY_INTERESTS',
          }),
        );
        final repository = TravelPreferencesRepositoryImpl(remote);

        await expectLater(
          repository.updatePreferences(const TravelPreferences.empty()),
          throwsA(
            isA<ValidationFailure>().having(
              (failure) => failure.fieldErrors.keys,
              'fieldErrors keys',
              contains('interests'),
            ),
          ),
        );
      },
    );

    test(
      'maps FOOD_NO_RESTRICTION_EXCLUSIVE to a foodPreferences-field ValidationFailure',
      () async {
        final remote = _FakeRemoteDataSource(
          updateError: _dioError(400, const {
            'errorCode': 'TRAVEL_PREFERENCES.FOOD_NO_RESTRICTION_EXCLUSIVE',
          }),
        );
        final repository = TravelPreferencesRepositoryImpl(remote);

        await expectLater(
          repository.updatePreferences(const TravelPreferences.empty()),
          throwsA(
            isA<ValidationFailure>().having(
              (failure) => failure.fieldErrors.keys,
              'fieldErrors keys',
              contains('foodPreferences'),
            ),
          ),
        );
      },
    );

    test('maps a 403 to the generic PermissionFailure', () async {
      final remote = _FakeRemoteDataSource(
        updateError: _dioError(403, const {
          'errorCode': 'TRAVEL_PREFERENCES.FORBIDDEN',
        }),
      );
      final repository = TravelPreferencesRepositoryImpl(remote);

      await expectLater(
        repository.updatePreferences(const TravelPreferences.empty()),
        throwsA(isA<PermissionFailure>()),
      );
    });
  });
}

DioException _dioError(int statusCode, Map<String, dynamic>? data) =>
    DioException(
      requestOptions: RequestOptions(path: '/api/v1/traveler/preferences'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/v1/traveler/preferences'),
        statusCode: statusCode,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );

final class _FakeRemoteDataSource implements TravelPreferencesRemoteDataSource {
  _FakeRemoteDataSource({
    this.optionsResponse,
    this.preferencesResponse,
    this.updateError,
  });

  final TravelPreferenceOptionsDto? optionsResponse;
  final TravelPreferencesDto? preferencesResponse;
  final Object? updateError;
  UpdateTravelPreferencesRequest? updateRequest;

  @override
  Future<TravelPreferenceOptionsDto> getOptions() async => optionsResponse!;

  @override
  Future<TravelPreferencesDto> getPreferences() async => preferencesResponse!;

  @override
  Future<TravelPreferencesDto> updatePreferences(
    UpdateTravelPreferencesRequest request,
  ) async {
    updateRequest = request;
    if (updateError != null) throw updateError!;
    return preferencesResponse!;
  }
}
