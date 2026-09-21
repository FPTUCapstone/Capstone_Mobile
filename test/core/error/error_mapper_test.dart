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

  test('maps travel group not found without leaking server details', () {
    final failure = ErrorMapper.toFailure(
      responseError(404, {
        'title': 'Travel group was not found.',
        'detail': 'Internal lookup diagnostics',
        'errorCode': 'travel_group.group_not_found',
      }),
    );

    expect(failure, isA<NotFoundFailure>());
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

  test('maps HTTP 409 already_active_member with groupId', () {
    final failure = ErrorMapper.toFailure(
      DioException(
        requestOptions: RequestOptions(path: '/travel-groups/join'),
        response: Response(
          requestOptions: RequestOptions(path: '/travel-groups/join'),
          statusCode: 409,
          data: {
            'errorCode': 'travel_group.already_active_member',
            'detail': 'Internal DB conflict occurred',
            'extensions': {'groupId': 42},
          },
        ),
      ),
    );

    expect(failure, isA<ConflictFailure>());
    final conflict = failure as ConflictFailure;
    expect(conflict.message, 'You are already a member of this travel group.');
    expect(conflict.groupId, 42);
  });

  test(
    'maps unknown HTTP 409 to safe ConflictFailure without leaking details',
    () {
      final failure = ErrorMapper.toFailure(
        DioException(
          requestOptions: RequestOptions(path: '/travel-groups/join'),
          response: Response(
            requestOptions: RequestOptions(path: '/travel-groups/join'),
            statusCode: 409,
            data: {
              'title': 'Internal SQL violation',
              'detail': 'Deadlock victim process 54',
            },
          ),
        ),
      );

      expect(failure, isA<ConflictFailure>());
      final conflict = failure as ConflictFailure;
      expect(conflict.message, 'Conflict occurred. Please try again.');
      expect(conflict.groupId, isNull);
    },
  );

  test(
    'maps HTTP 400 with unmapped technical error to safe ValidationFailure',
    () {
      final failure = ErrorMapper.toFailure(
        DioException(
          requestOptions: RequestOptions(path: '/travel-groups/join'),
          response: Response(
            requestOptions: RequestOptions(path: '/travel-groups/join'),
            statusCode: 400,
            data: {'detail': 'SqlException: Table not found'},
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'The input provided is invalid.');
    },
  );
}
