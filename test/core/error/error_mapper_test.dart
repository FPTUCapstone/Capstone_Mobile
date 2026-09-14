import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

void main() {
  DioException responseError(int status, Map<String, Object?> data) {
    final request = RequestOptions(path: '/api/v1/pois');
    return DioException(
      requestOptions: request,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: status,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
  }

  test('maps ValidationProblemDetails field errors', () {
    final failure = ErrorMapper.toFailure(
      responseError(400, {
        'title': 'One or more validation errors occurred.',
        'errors': {
          'search': ['Search cannot exceed 200 characters.'],
        },
      }),
    );

    expect(failure, isA<ValidationFailure>());
    expect((failure as ValidationFailure).fieldErrors['search'], [
      'Search cannot exceed 200 characters.',
    ]);
  });

  test('maps Poi.NotFound without leaking server details', () {
    final failure = ErrorMapper.toFailure(
      responseError(404, {
        'title': 'The requested point of interest was not found.',
        'errorCode': 'Poi.NotFound',
      }),
    );

    expect(failure, isA<NotFoundFailure>());
    expect(failure.message, 'Địa điểm không tồn tại hoặc đã đóng.');
  });

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
