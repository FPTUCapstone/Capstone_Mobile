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
