import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_preference_options_dto.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_preferences_dto.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/update_travel_preferences_request.dart';

abstract interface class TravelPreferencesRemoteDataSource {
  Future<TravelPreferenceOptionsDto> getOptions();

  Future<TravelPreferencesDto> getPreferences();

  Future<TravelPreferencesDto> updatePreferences(
    UpdateTravelPreferencesRequest request,
  );
}

/// UC-09: authenticated requests via the centralized Dio client, exactly
/// like every other authenticated Mobile endpoint. Unlike
/// `ChangePasswordRemoteDataSource`, `TravelerPreferencesController` returns
/// the DTO body directly — there is no `{ success, data }` envelope to
/// unwrap here.
final class TravelPreferencesRemoteDataSourceImpl
    implements TravelPreferencesRemoteDataSource {
  const TravelPreferencesRemoteDataSourceImpl(this._dioClient);

  static const _path = '/api/v1/traveler/preferences';

  final DioClient _dioClient;

  @override
  Future<TravelPreferenceOptionsDto> getOptions() async {
    final response = await _dioClient.dio.get<Map<String, dynamic>>(
      '$_path/options',
    );
    return TravelPreferenceOptionsDto.fromJson(_body(response.data));
  }

  @override
  Future<TravelPreferencesDto> getPreferences() async {
    final response = await _dioClient.dio.get<Map<String, dynamic>>(_path);
    return TravelPreferencesDto.fromJson(_body(response.data));
  }

  @override
  Future<TravelPreferencesDto> updatePreferences(
    UpdateTravelPreferencesRequest request,
  ) async {
    final response = await _dioClient.dio.put<Map<String, dynamic>>(
      _path,
      data: request.toJson(),
    );
    return TravelPreferencesDto.fromJson(_body(response.data));
  }

  Map<String, dynamic> _body(Map<String, dynamic>? response) {
    if (response == null) {
      throw const FormatException('Invalid API response.');
    }
    return response;
  }
}
