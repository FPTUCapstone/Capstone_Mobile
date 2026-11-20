import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_dashboard_metrics.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_dashboard_repository.dart';

final class OperatorDashboardRepositoryImpl
    implements OperatorDashboardRepository {
  const OperatorDashboardRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<OperatorDashboardMetrics> load() async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/operator/dashboard/metrics',
      );
      return _parse(response.data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const AuthenticationFailure();
      }
      if (error.response?.statusCode == 403) {
        throw const PermissionFailure();
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

  OperatorDashboardMetrics _parse(dynamic value) {
    if (value is! Map<String, dynamic>) throw const FormatException();
    int count(String key) {
      final number = value[key];
      if (number is! int || number < 0) throw const FormatException();
      return number;
    }

    DateTime day(String key) {
      final raw = value[key];
      if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
        throw const FormatException();
      }
      final parsed = DateTime.tryParse(raw);
      if (parsed == null || parsed.toIso8601String().substring(0, 10) != raw) {
        throw const FormatException();
      }
      return parsed;
    }

    final net = value['monthlyNetAmount'];
    final asOfRaw = value['asOfUtc'];
    final asOf = asOfRaw is String ? DateTime.tryParse(asOfRaw) : null;
    if (net is! num || !net.isFinite || asOf == null || !asOf.isUtc) {
      throw const FormatException();
    }
    final start = day('monthStart');
    final end = day('monthEndExclusive');
    if (start.day != 1 || end != DateTime(start.year, start.month + 1)) {
      throw const FormatException();
    }
    return OperatorDashboardMetrics(
      activeTourCount: count('activeTourCount'),
      monthlyBookingCount: count('monthlyBookingCount'),
      monthlyNetAmount: net,
      activeCouponCount: count('activeCouponCount'),
      asOfUtc: asOf,
      monthStart: start,
      monthEndExclusive: end,
    );
  }
}
