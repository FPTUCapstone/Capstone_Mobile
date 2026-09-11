import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

void main() {
  test('maps HTTP 401 to AuthenticationFailure', () {
    final failure = ErrorMapper.toFailure(
      DioException(
        requestOptions: RequestOptions(path: '/travel-groups'),
        response: Response(
          requestOptions: RequestOptions(path: '/travel-groups'),
          statusCode: 401,
        ),
      ),
    );

    expect(failure, isA<AuthenticationFailure>());
  });

  test('maps HTTP 403 to PermissionFailure', () {
    final failure = ErrorMapper.toFailure(
      DioException(
        requestOptions: RequestOptions(path: '/travel-groups'),
        response: Response(
          requestOptions: RequestOptions(path: '/travel-groups'),
          statusCode: 403,
        ),
      ),
    );

    expect(failure, isA<PermissionFailure>());
  });
}
