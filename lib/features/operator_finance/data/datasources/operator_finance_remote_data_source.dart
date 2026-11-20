import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';

abstract interface class OperatorFinanceRemoteDataSource {
  Future<Object?> loadReport(RevenueQuery query);
  Future<Object?> loadTourOptions();
  Future<Object?> loadSettlementHistory({int page = 1, int pageSize = 10});
}

final class DioOperatorFinanceRemoteDataSource
    implements OperatorFinanceRemoteDataSource {
  const DioOperatorFinanceRemoteDataSource(this._client);
  final DioClient _client;

  @override
  Future<Object?> loadReport(RevenueQuery query) =>
      _get('/api/v1/operator/revenue/report', {
        'startDate': _day(query.startDate),
        'endDate': _day(query.endDate),
        'granularity': query.granularity,
        'tourId': ?query.tourId,
        'page': query.page,
        'pageSize': query.pageSize,
      });

  @override
  Future<Object?> loadTourOptions() =>
      _get('/api/v1/operator/revenue/tours', null);

  @override
  Future<Object?> loadSettlementHistory({int page = 1, int pageSize = 10}) =>
      _get('/api/v1/operator/payout-settlements', {
        'page': page,
        'pageSize': pageSize,
      });

  Future<Object?> _get(String path, Map<String, Object?>? parameters) async {
    try {
      final response = await _client.dio.get<dynamic>(
        path,
        queryParameters: parameters,
      );
      final body = response.data;
      return body is String ? jsonDecode(body) : body;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401) throw const AuthenticationFailure();
      if (status == 403) throw const PermissionFailure();
      if (status == 400) {
        throw const ValidationFailure('Vui lòng kiểm tra bộ lọc báo cáo.');
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const NetworkFailure();
      }
      throw const ServerFailure();
    } on FormatException {
      throw const ServerFailure();
    }
  }

  static String _day(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}
