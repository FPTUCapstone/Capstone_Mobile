import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';

enum TravelerEmergencyLoadStatus { loading, ready, notFound, failure }

final class TravelerEmergencyState extends Equatable {
  const TravelerEmergencyState({
    this.status = TravelerEmergencyLoadStatus.loading,
    this.emergency,
    this.failure,
    this.actionFailure,
    this.isAcknowledging = false,
    this.isStale = false,
  });

  final TravelerEmergencyLoadStatus status;
  final TravelerEmergencyStatus? emergency;
  final Failure? failure;
  final Failure? actionFailure;
  final bool isAcknowledging;

  /// The notice could not be refreshed and may be out of date.
  final bool isStale;

  @override
  List<Object?> get props => [
    status,
    emergency,
    failure,
    actionFailure,
    isAcknowledging,
    isStale,
  ];
}
