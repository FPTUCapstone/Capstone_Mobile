import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/trip_history/data/models/trip_records_json.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';

const _invalidResponse = 'trip_history.invalid_response';
const _invalidDateRange = 'trip_history.invalid_date_range';

final class TripRecordsRepositoryImpl implements TripRecordsRepository {
  const TripRecordsRepositoryImpl(this._client);

  final DioClient _client;

  static const _path = '/api/v1/traveler/trips';

  @override
  Future<TripRecordPage> getPage(TripRecordsQuery query) async {
    final parameters = <String, String>{
      'tab': _tabWire(query.tab),
      'page': '${query.page}',
      'pageSize': '${query.pageSize}',
    };
    final tripType = query.tripType.wireValue;
    if (tripType != null) parameters['tripType'] = tripType;
    final from = query.startDate;
    final to = query.endDate;
    if (from != null) parameters['fromDate'] = _day(from);
    if (to != null) parameters['toDate'] = _day(to);

    final body = await _get(_path, parameters);
    try {
      return TripRecordsJson.page(body);
    } on Object {
      throw const ServerFailure(_invalidResponse);
    }
  }

  @override
  Future<TripRecordDetail> getDetail(TripRecordKind kind, int id) async {
    final body = await _get('$_path/${kind.wireKind}/$id', null);
    try {
      final detail = TripRecordsJson.detail(body);
      // A detail for another record than the one asked for is never shown.
      if (detail.record.kind != kind || detail.record.id != id) {
        throw const FormatException('Detail does not match the request.');
      }
      return detail;
    } on Object {
      throw const ServerFailure(_invalidResponse);
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
      throw const ServerFailure(_invalidResponse);
    }
  }

  Failure _failure(DioException error) {
    final status = error.response?.statusCode;
    final code = _errorCode(error.response?.data);
    if (status == 401) return const AuthenticationFailure();
    if (status == 403) return const PermissionFailure();
    if (status == 404) return const NotFoundFailure();
    if (status == 400 && code == _invalidDateRange) {
      return const ValidationFailure(_invalidDateRange);
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

  static String _tabWire(TripStatus tab) => switch (tab) {
    TripStatus.upcoming => 'Upcoming',
    TripStatus.completed => 'Completed',
    TripStatus.cancelled => 'Cancelled',
  };

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
