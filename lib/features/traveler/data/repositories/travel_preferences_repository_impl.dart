import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/travel_preferences_remote_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/mappers/travel_preferences_mapper.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preference_options.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preferences.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_preferences_repository.dart';

/// UC-09 spec §5 error mapping, ahead of the shared [ErrorMapper]: every
/// `TRAVEL_PREFERENCES.*` code gets a dedicated safe message. `401`/`403`/
/// network/`5xx` fall through to the generic mapper, matching
/// `ChangePasswordRepositoryImpl`'s precedent.
final class TravelPreferencesRepositoryImpl
    implements TravelPreferencesRepository {
  const TravelPreferencesRepositoryImpl(this._remoteDataSource);

  final TravelPreferencesRemoteDataSource _remoteDataSource;

  @override
  Future<TravelPreferenceOptions> getOptions() async {
    try {
      final dto = await _remoteDataSource.getOptions();
      return dto.toDomain();
    } catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<TravelPreferences> getPreferences() async {
    try {
      final dto = await _remoteDataSource.getPreferences();
      return dto.toDomain();
    } catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<TravelPreferences> updatePreferences(
    TravelPreferences preferences,
  ) async {
    try {
      final dto = await _remoteDataSource.updatePreferences(
        preferences.toRequest(),
      );
      return dto.toDomain();
    } catch (error) {
      throw _toFailure(error);
    }
  }

  Failure _toFailure(Object error) {
    if (error is FormatException) {
      return const ServerFailure('Something went wrong. Please try again.');
    }
    if (error is DioException) {
      final errorCode = ErrorMapper.extractErrorCode(error.response?.data);
      switch (errorCode) {
        case 'TRAVEL_PREFERENCES.TOO_MANY_INTERESTS':
          return const ValidationFailure(
            'You can select up to 10 interests.',
            fieldErrors: {
              'interests': ['You can select up to 10 interests.'],
            },
          );
        case 'TRAVEL_PREFERENCES.FOOD_NO_RESTRICTION_EXCLUSIVE':
          return const ValidationFailure(
            'No restriction cannot be combined with other food preferences.',
            fieldErrors: {
              'foodPreferences': [
                'No restriction cannot be combined with other food preferences.',
              ],
            },
          );
        case 'TRAVEL_PREFERENCES.INVALID_OPTION':
          return const ValidationFailure(
            'One or more selections are no longer available. Please reload and try again.',
          );
        case 'TRAVEL_PREFERENCES.VALUE_TOO_LONG':
          return const ValidationFailure(
            'One or more selections are too long. Please reload and try again.',
          );
      }
    }

    final failure = ErrorMapper.toFailure(error);
    if (failure is ServerFailure || failure is UnknownFailure) {
      return const ServerFailure(
        'Something went wrong. Please try again later.',
      );
    }
    return failure;
  }
}
