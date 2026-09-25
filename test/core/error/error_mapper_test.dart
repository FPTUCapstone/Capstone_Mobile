import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

void main() {
  DioException responseError({
    required int statusCode,
    Object? data,
    String path = '/travel-groups',
  }) {
    final request = RequestOptions(path: path);
    return DioException(
      requestOptions: request,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: statusCode,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
  }

  test('maps ValidationProblemDetails field errors', () {
    final failure = ErrorMapper.toFailure(
      responseError(
        statusCode: 400,
        data: {
          'title': 'One or more validation errors occurred.',
          'errors': {
            'search': ['Search cannot exceed 200 characters.'],
          },
        },
      ),
    );

    expect(failure, isA<ValidationFailure>());
    expect((failure as ValidationFailure).fieldErrors['search'], [
      'Search cannot exceed 200 characters.',
    ]);
  });

  test('maps Poi.NotFound without leaking server details', () {
    final failure = ErrorMapper.toFailure(
      responseError(
        statusCode: 404,
        path: '/api/v1/pois',
        data: {
          'title': 'The requested point of interest was not found.',
          'errorCode': 'Poi.NotFound',
        },
      ),
    );

    expect(failure, isA<NotFoundFailure>());
    expect(failure.message, const NotFoundFailure().message);
  });

  test('maps a missing travel group itinerary to a safe not-found failure', () {
    final failure = ErrorMapper.toFailure(
      responseError(
        statusCode: 404,
        data: {'errorCode': 'travel_group.itinerary_not_found'},
      ),
    );

    expect(failure, isA<NotFoundFailure>());
    expect(
      failure.message,
      'The selected itinerary was not found. Please choose another itinerary.',
    );
  });

  test('maps travel group not found without leaking server details', () {
    final failure = ErrorMapper.toFailure(
      responseError(
        statusCode: 404,
        data: {
          'title': 'Travel group was not found.',
          'detail': 'Internal lookup diagnostics',
          'errorCode': 'travel_group.group_not_found',
        },
      ),
    );

    expect(failure, isA<NotFoundFailure>());
  });

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
        data: {
          'title': 'SqlException: Table not found',
          'detail': 'SqlException: Table not found',
        },
      ),
    );

    expect(failure, isA<ValidationFailure>());
    expect(failure.message, 'The input provided is invalid.');
  });

  test('maps a connection failure to NetworkFailure', () {
    final request = RequestOptions(path: '/travel-groups');
    final failure = ErrorMapper.toFailure(
      DioException.connectionError(
        requestOptions: request,
        reason: 'Connection interrupted.',
      ),
    );

    expect(failure, isA<NetworkFailure>());
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
    expect(
      (failure as ConflictFailure).isIdempotencyKeyPayloadMismatch,
      isTrue,
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

  test('maps MSG127 to ServerFailure regardless of HTTP 400', () {
    final failure = ErrorMapper.toFailure(
      responseError(statusCode: 400, data: {'code': 'MSG127'}),
    );

    expect(failure, isA<ServerFailure>());
  });

  test('maps HTTP 429 to RateLimitFailure', () {
    final failure = ErrorMapper.toFailure(responseError(statusCode: 429));

    expect(failure, isA<RateLimitFailure>());
  });

  test('extracts an error code from every supported Backend envelope', () {
    final cases = <Object, String>{
      {'errorCode': 'TOP_LEVEL_ERROR_CODE'}: 'TOP_LEVEL_ERROR_CODE',
      {'code': 'TOP_LEVEL_CODE'}: 'TOP_LEVEL_CODE',
      {
        'extensions': {'errorCode': 'EXTENSION_ERROR_CODE'},
      }: 'EXTENSION_ERROR_CODE',
    };

    for (final entry in cases.entries) {
      expect(ErrorMapper.extractErrorCode(entry.key), entry.value);
    }
  });
}
