import 'package:equatable/equatable.dart';

/// One place visited on a tour day, in visiting order.
final class TourItineraryStop extends Equatable {
  const TourItineraryStop({
    required this.poiName,
    this.address,
    this.plannedTime,
    this.stayMinutes,
    this.notes,
  });

  final String poiName;
  final String? address;

  /// Planned arrival as "HH:mm", Vietnam local time (itineraries are planned there).
  final String? plannedTime;
  final int? stayMinutes;
  final String? notes;

  @override
  List<Object?> get props => [
    poiName,
    address,
    plannedTime,
    stayMinutes,
    notes,
  ];
}
