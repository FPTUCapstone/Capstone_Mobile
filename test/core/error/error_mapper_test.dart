import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

void main() {
  test('maps HTTP 403 to PermissionFailure', () {
    final requestOptions = RequestOptions(
      path: '/api/v1/travel-groups/1/invitation',
    );
    final error = DioException(
      requestOptions: requestOptions,
      response: Response<void>(requestOptions: requestOptions, statusCode: 403),
    );

    expect(ErrorMapper.toFailure(error), isA<PermissionFailure>());
  });
}
