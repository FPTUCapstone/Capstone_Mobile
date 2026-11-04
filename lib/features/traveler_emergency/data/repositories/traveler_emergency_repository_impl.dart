import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/data/datasources/traveler_emergency_remote_data_source.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/repositories/traveler_emergency_repository.dart';

final class TravelerEmergencyRepositoryImpl
    implements TravelerEmergencyRepository {
  const TravelerEmergencyRepositoryImpl(this._remote);

  final TravelerEmergencyRemoteDataSource _remote;

  @override
  Future<List<TravelerEmergencyNotice>> getNotices() async {
    try {
      return await _remote.getNotices();
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<TravelerEmergencyStatus> getStatus(int bookingId) async {
    try {
      return await _remote.getStatus(bookingId);
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<DateTime> acknowledge(int bookingId) async {
    try {
      return await _remote.acknowledge(bookingId);
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
