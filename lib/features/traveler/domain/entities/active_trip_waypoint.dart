import 'package:equatable/equatable.dart';

final class ActiveTripWaypoint extends Equatable {
  const ActiveTripWaypoint({
    required this.id,
    required this.name,
    required this.orderIndex,
    required this.plannedArrival,
    required this.stayDurationMinutes,
    required this.latitude,
    required this.longitude,
    this.isReached = false,
  });

  final int id;
  final String name;
  final int orderIndex;
  final DateTime plannedArrival;
  final int stayDurationMinutes;
  final double latitude;
  final double longitude;
  final bool isReached;

  ActiveTripWaypoint copyWith({
    int? id,
    String? name,
    int? orderIndex,
    DateTime? plannedArrival,
    int? stayDurationMinutes,
    double? latitude,
    double? longitude,
    bool? isReached,
  }) {
    return ActiveTripWaypoint(
      id: id ?? this.id,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      plannedArrival: plannedArrival ?? this.plannedArrival,
      stayDurationMinutes: stayDurationMinutes ?? this.stayDurationMinutes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isReached: isReached ?? this.isReached,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    orderIndex,
    plannedArrival,
    stayDurationMinutes,
    latitude,
    longitude,
    isReached,
  ];
}
