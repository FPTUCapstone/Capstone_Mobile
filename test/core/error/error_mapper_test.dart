import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

void main() {
  DioException responseError({
    required int statusCode,
    dynamic data,
    String path = '/travel-groups',
  }) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
    ),
  );

  test('maps HTTP 401 to AuthenticationFailure', () {
    final failure = ErrorMapper.toFailure(responseError(statusCode: 401));

    expect(failure, isA<AuthenticationFailure>());
  });

  test('maps HTTP 403 to PermissionFailure', () {
    final failure = ErrorMapper.toFailure(responseError(statusCode: 403));

    expect(failure, isA<PermissionFailure>());
  });

  test(
    'maps validation errors to ValidationFailure with the field message',
    () {
      final failure = ErrorMapper.toFailure(
        responseError(
          statusCode: 400,
          data: {
            'errors': {
              'GroupName': ['Group name is required.'],
            },
          },
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Group name is required.');
    },
  );

  test('maps an idempotency payload mismatch to a safe validation message', () {
    final failure = ErrorMapper.toFailure(
      responseError(
        statusCode: 400,
        data: {'errorCode': 'travel_group.idempotency_key_payload_mismatch'},
      ),
    );

    expect(failure, isA<ValidationFailure>());
    expect(
      failure.message,
      'A conflicting request with different request data is already in progress. Please try again.',
    );
  });

  test(
    'maps HTTP 400 without a supported message to default ValidationFailure',
    () {
      final failure = ErrorMapper.toFailure(responseError(statusCode: 400));

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'The input provided is invalid.');
    },
  );

  test('does not expose an unmapped technical HTTP 400 detail', () {
    final failure = ErrorMapper.toFailure(
      responseError(
        statusCode: 400,
        path: '/travel-groups/join',
        data: {'detail': 'SqlException: Table not found'},
      ),
    );

    expect(failure, isA<ValidationFailure>());
    expect(failure.message, 'The input provided is invalid.');
  });

  test('maps an active membership conflict with its group id', () {
    final failure = ErrorMapper.toFailure(
      responseError(
        statusCode: 409,
        path: '/travel-groups/join',
        data: {
          'errorCode': 'travel_group.already_active_member',
          'extensions': {'groupId': 42},
        },
      ),
    );

    expect(failure, isA<ConflictFailure>());
    final conflict = failure as ConflictFailure;
    expect(conflict.message, 'You are already a member of this travel group.');
    expect(conflict.groupId, 42);
  });

  test('maps an idempotency payload conflict to a safe message', () {
    final failure = ErrorMapper.toFailure(
      responseError(
        statusCode: 409,
        data: {'errorCode': 'travel_group.idempotency_key_payload_mismatch'},
      ),
    );

    expect(failure, isA<ConflictFailure>());
    expect(
      failure.message,
      'A conflicting request with different request data is already in progress. Please try again.',
    );
  });

  test('does not expose an unknown HTTP 409 detail', () {
    final failure = ErrorMapper.toFailure(
      responseError(
        statusCode: 409,
        data: {
          'title': 'Internal SQL violation',
          'detail': 'Deadlock victim process 54',
        },
      ),
    );

    expect(failure, isA<ConflictFailure>());
    expect(failure.message, 'Conflict occurred. Please try again.');
  });

  test('maps HTTP >= 500 to ServerFailure', () {
    final failure = ErrorMapper.toFailure(responseError(statusCode: 500));

    expect(failure, isA<ServerFailure>());
  });
}
