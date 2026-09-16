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

  test(
    'maps HTTP 400 with ProblemDetails title to ValidationFailure with custom message',
    () {
      final failure = ErrorMapper.toFailure(
        DioException(
          requestOptions: RequestOptions(path: '/travel-groups'),
          response: Response(
            requestOptions: RequestOptions(path: '/travel-groups'),
            statusCode: 400,
            data: {'title': 'A valid Idempotency-Key header is required.'},
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'A valid Idempotency-Key header is required.');
    },
  );

  test(
    'maps HTTP 400 with ProblemDetails detail to ValidationFailure with detail',
    () {
      final failure = ErrorMapper.toFailure(
        DioException(
          requestOptions: RequestOptions(path: '/travel-groups'),
          response: Response(
            requestOptions: RequestOptions(path: '/travel-groups'),
            statusCode: 400,
            data: {
              'title': 'Bad Request',
              'detail': 'Group name cannot be blank.',
            },
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Group name cannot be blank.');
    },
  );

  test('maps HTTP 400 with validation errors map to ValidationFailure', () {
    final failure = ErrorMapper.toFailure(
      DioException(
        requestOptions: RequestOptions(path: '/travel-groups'),
        response: Response(
          requestOptions: RequestOptions(path: '/travel-groups'),
          statusCode: 400,
          data: {
            'errors': {
              'GroupName': ['Group name is required.'],
            },
          },
        ),
      ),
    );

    expect(failure, isA<ValidationFailure>());
    expect(failure.message, 'Group name is required.');
  });

  test('maps HTTP 400 without body to default ValidationFailure', () {
    final failure = ErrorMapper.toFailure(
      DioException(
        requestOptions: RequestOptions(path: '/travel-groups'),
        response: Response(
          requestOptions: RequestOptions(path: '/travel-groups'),
          statusCode: 400,
        ),
      ),
    );

    expect(failure, isA<ValidationFailure>());
    expect(failure.message, 'The provided data is invalid.');
  });

  test(
    'maps HTTP 409 with ProblemDetails to ConflictFailure with custom message',
    () {
      final failure = ErrorMapper.toFailure(
        DioException(
          requestOptions: RequestOptions(path: '/travel-groups'),
          response: Response(
            requestOptions: RequestOptions(path: '/travel-groups'),
            statusCode: 409,
            data: {'title': 'Idempotency key payload mismatch.'},
          ),
        ),
      );

      expect(failure, isA<ConflictFailure>());
      expect(failure.message, 'Idempotency key payload mismatch.');
    },
  );

  test('maps HTTP 409 without body to default ConflictFailure', () {
    final failure = ErrorMapper.toFailure(
      DioException(
        requestOptions: RequestOptions(path: '/travel-groups'),
        response: Response(
          requestOptions: RequestOptions(path: '/travel-groups'),
          statusCode: 409,
        ),
      ),
    );

    expect(failure, isA<ConflictFailure>());
    expect(
      failure.message,
      'The operation is in conflict or already being processed.',
    );
  });

  test('maps HTTP >= 500 to ServerFailure', () {
    final failure = ErrorMapper.toFailure(
      DioException(
        requestOptions: RequestOptions(path: '/travel-groups'),
        response: Response(
          requestOptions: RequestOptions(path: '/travel-groups'),
          statusCode: 500,
        ),
      ),
    );

    expect(failure, isA<ServerFailure>());
  });
}
