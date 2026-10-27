import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/models/operator_bookings_json.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';

const operatorBookingInvalidResponse = 'operator_booking.invalid_response';
const operatorBookingInvalidDateRange = 'operator_booking.invalid_date_range';

final class OperatorBookingsRepositoryImpl
    implements OperatorBookingsRepository {
  const OperatorBookingsRepositoryImpl(this._client);

  final DioClient _client;

  static const _path = '/api/v1/operator/bookings';
  static const _tourOptionsPath = '/api/v1/operator/revenue/tours';

  @override
  Future<OperatorBookingsPage> getPage(OperatorBookingsQuery query) async {
    final parameters = <String, String>{
      'tourId': ?query.tourId,
      'status': ?query.status?.wire,
      'departureFrom': ?_day(query.departureFrom),
      'departureTo': ?_day(query.departureTo),
      'keyword': ?_keyword(query.keyword),
      'pageNumber': '${query.page}',
      'pageSize': '${query.pageSize}',
    };

    final body = await _get(_path, parameters);
    try {
      return OperatorBookingsJson.page(body);
    } on Object {
      throw const ServerFailure(operatorBookingInvalidResponse);
    }
  }

  @override
  Future<OperatorBookingDetail> getDetail(String bookingId) async {
    // A live booking id is a digit string; anything else is never sent to the backend.
    if (!RegExp(r'^\d+$').hasMatch(bookingId)) throw const NotFoundFailure();

    final body = await _get('$_path/$bookingId', null);
    try {
      final detail = OperatorBookingsJson.detail(body);
      // A detail for another booking than the one asked for is never shown.
      if (detail.bookingId != bookingId) {
        throw const FormatException('Detail does not match the request.');
      }
      return detail;
    } on Object {
      throw const ServerFailure(operatorBookingInvalidResponse);
    }
  }

  @override
  Future<List<OperatorBookingTourOption>> getTourOptions() async {
    final body = await _get(_tourOptionsPath, null);
    try {
      return OperatorBookingsJson.tourOptions(body);
    } on Object {
      throw const ServerFailure(operatorBookingInvalidResponse);
    }
  }

  Future<Object?> _get(String path, Map<String, String>? parameters) async {
    try {
      final response = await _client.dio.get<String>(
        path,
        queryParameters: parameters,
        options: Options(responseType: ResponseType.plain),
      );
      return jsonDecode(response.data ?? '');
    } on DioException catch (error) {
      throw _failure(error);
    } on Object {
      throw const ServerFailure(operatorBookingInvalidResponse);
    }
  }

  Failure _failure(DioException error) {
    final status = error.response?.statusCode;
    final code = _errorCode(error.response?.data);
    if (status == 401) return const AuthenticationFailure();
    if (status == 403) return const PermissionFailure();
    if (status == 404) return const NotFoundFailure();
    if (status == 400 && code == operatorBookingInvalidDateRange) {
      return const ValidationFailure(operatorBookingInvalidDateRange);
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure();
    }
    // Any other answer is reported generically: no server text reaches the user.
    return const ServerFailure();
  }

  String? _errorCode(Object? data) {
    if (data is! String) return null;
    try {
      final decoded = jsonDecode(data);
      final code = decoded is Map<String, dynamic>
          ? decoded['errorCode']
          : null;
      return code is String ? code : null;
    } on Object {
      return null;
    }
  }

  static String? _keyword(String? keyword) {
    final trimmed = keyword?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _day(DateTime? date) => date == null
      ? null
      : '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
}
