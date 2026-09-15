import 'package:equatable/equatable.dart';

final class SelectablePoi extends Equatable {
  const SelectablePoi({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.averageVisitDurationMinutes,
    required this.openingHoursKnown,
    required this.hasShelter,
    this.address,
    this.estimatedVisitCost,
    this.categoryName,
  });

  final int id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int averageVisitDurationMinutes;
  final double? estimatedVisitCost;
  final bool openingHoursKnown;
  final bool hasShelter;
  final String? categoryName;

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    latitude,
    longitude,
    averageVisitDurationMinutes,
    estimatedVisitCost,
    openingHoursKnown,
    hasShelter,
    categoryName,
  ];
}
