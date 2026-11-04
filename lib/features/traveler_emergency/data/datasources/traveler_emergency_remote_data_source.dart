import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/data/models/traveler_emergency_status_model.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';

abstract interface class TravelerEmergencyRemoteDataSource {
  Future<List<TravelerEmergencyNotice>> getNotices();

  Future<TravelerEmergencyStatus> getStatus(int bookingId);

  Future<DateTime> acknowledge(int bookingId);
}

final class DioTravelerEmergencyRemoteDataSource
    implements TravelerEmergencyRemoteDataSource {
  DioTravelerEmergencyRemoteDataSource(DioClient client) : _dio = client.dio;

  final Dio _dio;

  static String _path(int bookingId) =>
      '/api/v1/traveler/tour-bookings/$bookingId/emergency-status';

  @override
  Future<List<TravelerEmergencyNotice>> getNotices() async {
    final response = await _dio.get<Object?>(
      '/api/v1/traveler/tour-bookings/emergency-notices',
    );
    return TravelerEmergencyStatusModel.notices(response.data);
  }

  @override
  Future<TravelerEmergencyStatus> getStatus(int bookingId) async {
    final response = await _dio.get<Object?>(_path(bookingId));
    return TravelerEmergencyStatusModel.fromJson(response.data);
  }

  @override
  Future<DateTime> acknowledge(int bookingId) async {
    final response = await _dio.post<Object?>(
      '${_path(bookingId)}/acknowledge',
    );
    return TravelerEmergencyStatusModel.acknowledgedAt(response.data);
  }
}
