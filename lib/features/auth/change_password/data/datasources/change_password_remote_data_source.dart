import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/models/change_password_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';

abstract interface class ChangePasswordRemoteDataSource {
  Future<SessionResponseDto> changePassword(ChangePasswordRequest request);
}

final class ChangePasswordRemoteDataSourceImpl
    implements ChangePasswordRemoteDataSource {
  const ChangePasswordRemoteDataSourceImpl(this._dioClient);

  static const _path = '/api/v1/auth/change-password';

  final DioClient _dioClient;

  /// Authenticated request: no `skipAuth` extra, so the centralized Dio
  /// client's auth interceptor attaches the current access token exactly as
  /// it does for every other authenticated endpoint.
  @override
  Future<SessionResponseDto> changePassword(
    ChangePasswordRequest request,
  ) async {
    final response = await _dioClient.dio.post<Map<String, dynamic>>(
      _path,
      data: request.toJson(),
    );
    final data = _unwrap(response.data);
    return SessionResponseDto.fromJson(data);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (response?['success'] != true || data is! Map<String, dynamic>) {
      throw const FormatException('Invalid API response envelope.');
    }
    return data;
  }
}
