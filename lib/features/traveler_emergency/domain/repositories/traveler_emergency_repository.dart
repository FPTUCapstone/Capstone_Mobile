import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';

abstract interface class TravelerEmergencyRepository {
  /// Every notice for the signed-in Traveler, newest first.
  Future<List<TravelerEmergencyNotice>> getNotices();

  Future<TravelerEmergencyStatus> getStatus(int bookingId);

  /// Records receipt and returns the Backend's acknowledgement time.
  Future<DateTime> acknowledge(int bookingId);
}
