import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/push/push_device_repository.dart';

final class DioPushDeviceRepository implements PushDeviceRepository {
  const DioPushDeviceRepository(this._client);

  final DioClient _client;

  @override
  Future<void> register({
    required String installationId,
    required String token,
  }) async {
    try {
      await _client.dio.put<void>(
        '/api/v1/me/push-devices/$installationId',
        data: {'token': token},
      );
    } on DioException catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<void> remove(String installationId) async {
    try {
      await _client.dio.delete<void>('/api/v1/me/push-devices/$installationId');
    } on DioException catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
