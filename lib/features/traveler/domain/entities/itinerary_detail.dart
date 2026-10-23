import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

final class ItineraryDetail extends Equatable {
  const ItineraryDetail({
    required this.itineraryId,
    required this.schedulingRequestId,
    required this.title,
    required this.version,
    required this.status,
    required this.validFrom,
    required this.validTo,
    required this.canManage,
    required this.totalEstimatedCost,
    required this.totalDurationMinutes,
    required this.items,
    this.isNavigationInProgress = false,
    this.transportMode,
    this.startLocation,
    this.endLocation,
    this.budgetVnd,
  });

  final int itineraryId;
  final int schedulingRequestId;
  final String? title;
  final int version;
  final String status;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool canManage;
  final double totalEstimatedCost;
  final int totalDurationMinutes;
  final List<ItineraryDetailItem> items;

  /// Someone is navigating this trip on the app: it cannot be regenerated or
  /// adjusted until that navigation ends.
  final bool isNavigationInProgress;

  /// The trip's default transport; a leg may use another one. Null from older
  /// backends.
  final TransportMode? transportMode;
  final ItineraryLocation? startLocation;
  final ItineraryLocation? endLocation;

  /// The budget of the scheduling request; null when none was set.
  final double? budgetVnd;

  /// The owner may change the plan only while nobody is navigating it.
  bool get canEdit => canManage && !isNavigationInProgress;

  List<ItineraryDetailItem> get visitItems => items
      .where(
        (item) =>
            item.itemKind == ItineraryItemKind.visit && item.poiId != null,
      )
      .toList(growable: false);

  @override
  List<Object?> get props => [
    itineraryId,
    schedulingRequestId,
    title,
    version,
    status,
    validFrom,
    validTo,
    canManage,
    totalEstimatedCost,
    totalDurationMinutes,
    items,
    isNavigationInProgress,
    transportMode,
    startLocation,
    endLocation,
    budgetVnd,
  ];
}

/// Where the trip starts or ends. [address] is null for a raw coordinate.
final class ItineraryLocation extends Equatable {
  const ItineraryLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;

  @override
  List<Object?> get props => [latitude, longitude, address];
}

final class ItineraryDetailItem extends Equatable {
  const ItineraryDetailItem({
    required this.itemId,
    required this.sequenceNo,
    required this.poiId,
    required this.poiName,
    required this.category,
    required this.itemKind,
    required this.plannedArrival,
    required this.plannedDeparture,
    required this.travelDurationFromPreviousMinutes,
    required this.stayDurationMinutes,
    required this.estimatedCost,
    required this.isMandatory,
    required this.recommendationReason,
    required this.isUnavailable,
    this.travelDistanceFromPreviousMeters,
    this.transportModeFromPrevious,
    this.costKind,
    this.address,
    this.latitude,
    this.longitude,
  });

  final int itemId;
  final int sequenceNo;
  final int? poiId;
  final String? poiName;
  final String? category;
  final ItineraryItemKind itemKind;
  final DateTime plannedArrival;
  final DateTime plannedDeparture;
  final int? travelDurationFromPreviousMinutes;
  final int stayDurationMinutes;
  final double? estimatedCost;
  final bool isMandatory;
  final String? recommendationReason;
  final bool isUnavailable;

  /// Road distance of the leg that reaches this stop; null for older plans.
  final int? travelDistanceFromPreviousMeters;

  /// Transport used to reach this stop; null means the trip default.
  final TransportMode? transportModeFromPrevious;
  final CostKind? costKind;
  final String? address;
  final double? latitude;
  final double? longitude;

  bool get isFood => costKind == CostKind.averageSpend;

  @override
  List<Object?> get props => [
    itemId,
    sequenceNo,
    poiId,
    poiName,
    category,
    itemKind,
    plannedArrival,
    plannedDeparture,
    travelDurationFromPreviousMinutes,
    stayDurationMinutes,
    estimatedCost,
    isMandatory,
    recommendationReason,
    isUnavailable,
    travelDistanceFromPreviousMeters,
    transportModeFromPrevious,
    costKind,
    address,
    latitude,
    longitude,
  ];
}
