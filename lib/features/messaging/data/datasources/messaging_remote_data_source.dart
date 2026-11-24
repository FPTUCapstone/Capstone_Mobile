import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';

/// Uses the existing authenticated client and its session interceptor.
final class MessagingRemoteDataSource {
  const MessagingRemoteDataSource(this._client);
  final DioClient _client;

  Future<Object?> get(
    String path, {
    Map<String, Object> query = const {},
  }) async {
    final response = await _client.dio.get<Object?>(
      path,
      queryParameters: query,
    );
    _status(response, 200);
    return response.data;
  }

  Future<Object?> post(String path, {Object? body, int status = 200}) async {
    final response = await _client.dio.post<Object?>(path, data: body);
    _status(response, status);
    return response.data;
  }

  static void _status(Response<Object?> response, int expected) {
    if (response.statusCode != expected) {
      throw const FormatException('Unexpected messaging status.');
    }
  }
}
