import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_location.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/group_location_repository.dart';

final class GroupLocationRepositoryImpl implements GroupLocationRepository {
  const GroupLocationRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  final DioClient _dioClient;

  String _path(int groupId) => '/api/v1/travel-groups/$groupId';

  @override
  Future<List<int>> getEnabledGroupIds() async {
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        '/api/v1/travel-groups/location-sharing/active',
      );
      final raw = response.data?['groupIds'];
      if (raw is! List || raw.any((id) => id is! int || id <= 0)) {
        throw const FormatException('Invalid enabled groups response.');
      }
      return List<int>.unmodifiable(raw.cast<int>());
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<LocationSharingSetting> getSetting(int groupId) async {
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        '${_path(groupId)}/location-sharing',
      );
      return _setting(response.data, groupId);
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<LocationSharingSetting> updateSetting(
    int groupId,
    bool enabled,
  ) async {
    try {
      final response = await _dioClient.dio.put<Map<String, dynamic>>(
        '${_path(groupId)}/location-sharing',
        data: {'enabled': enabled},
      );
      return _setting(response.data, groupId);
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<List<GroupLocation>> getLocations(int groupId) async {
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        '${_path(groupId)}/locations',
      );
      final data = response.data;
      if (data?['groupId'] != groupId || data?['locations'] is! List) {
        throw const FormatException('Invalid group locations response.');
      }
      return (data!['locations'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Invalid member location.');
            }
            final userId = raw['userId'];
            final latitude = _coordinate(raw['latitude'], -90, 90);
            final longitude = _coordinate(raw['longitude'], -180, 180);
            final time = DateTime.tryParse(
              raw['recordedAtUtc'] is String
                  ? raw['recordedAtUtc'] as String
                  : '',
            );
            if (userId is! int || userId <= 0 || time == null) {
              throw const FormatException('Invalid member location.');
            }
            return GroupLocation(
              userId: userId,
              latitude: latitude,
              longitude: longitude,
              recordedAtUtc: time.toUtc(),
            );
          })
          .toList(growable: false);
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<void> publish(
    int groupId,
    DeviceGroupLocation location,
    String sessionVersion,
  ) async {
    try {
      await _dioClient.dio.put<Map<String, dynamic>>(
        '${_path(groupId)}/location',
        data: {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'sessionVersion': sessionVersion,
        },
      );
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<void> clear(int groupId) async {
    try {
      await _dioClient.dio.delete<void>('${_path(groupId)}/location');
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  static LocationSharingSetting _setting(
    Map<String, dynamic>? data,
    int groupId,
  ) {
    if (data?['groupId'] != groupId || data?['enabled'] is! bool) {
      throw const FormatException('Invalid location sharing setting.');
    }
    final rawTime = data!['updatedAtUtc'];
    final rawVersion = data['sessionVersion'];
    if (data['enabled'] == true &&
        (rawVersion is! String || rawVersion.isEmpty)) {
      throw const FormatException('Missing location sharing session version.');
    }
    final updatedAtUtc = rawTime is String
        ? DateTime.tryParse(rawTime)?.toUtc()
        : null;
    if (rawTime != null && updatedAtUtc == null) {
      throw const FormatException('Invalid setting timestamp.');
    }
    return LocationSharingSetting(
      groupId: groupId,
      enabled: data['enabled'] as bool,
      updatedAtUtc: updatedAtUtc,
      sessionVersion: rawVersion is String ? rawVersion : null,
    );
  }

  static double _coordinate(Object? raw, double min, double max) {
    if (raw is! num || !raw.isFinite || raw < min || raw > max) {
      throw const FormatException('Invalid GPS coordinate.');
    }
    return raw.toDouble();
  }
}
