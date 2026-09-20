import 'package:equatable/equatable.dart';

String formatPlanningDateTime(DateTime value) {
  final vietnamTime = DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
  return '${vietnamTime.toIso8601String().replaceFirst('Z', '')}+07:00';
}

enum TransportMode { walking, motorbike, car, publicTransit }

enum RestPreference { auto, none, frequent }

enum ItineraryItemKind { visit, rest }

final class GeneratedItinerary extends Equatable {
  const GeneratedItinerary({
    required this.schedulingRequestId,
    required this.itineraryId,
    required this.title,
    required this.status,
    required this.totalEstimatedCost,
    required this.totalDurationMinutes,
    required this.items,
  });

  final int schedulingRequestId;
  final int itineraryId;
  final String title;
  final String status;
  final double totalEstimatedCost;
  final int totalDurationMinutes;
  final List<GeneratedItineraryItem> items;

  @override
  List<Object?> get props => [
    schedulingRequestId,
    itineraryId,
    title,
    status,
    totalEstimatedCost,
    totalDurationMinutes,
    items,
  ];
}

final class GeneratedItineraryItem extends Equatable {
  const GeneratedItineraryItem({
    required this.sequenceNo,
    required this.itemKind,
    required this.plannedArrival,
    required this.plannedDeparture,
    required this.stayDurationMinutes,
    required this.isMandatory,
    this.poiId,
    this.poiName,
    this.estimatedCost,
    this.recommendationReason,
  });

  final int sequenceNo;
  final int? poiId;
  final String? poiName;
  final ItineraryItemKind itemKind;
  final DateTime plannedArrival;
  final DateTime plannedDeparture;
  final int stayDurationMinutes;
  final double? estimatedCost;
  final bool isMandatory;
  final String? recommendationReason;

  @override
  List<Object?> get props => [
    sequenceNo,
    poiId,
    poiName,
    itemKind,
    plannedArrival,
    plannedDeparture,
    stayDurationMinutes,
    estimatedCost,
    isMandatory,
    recommendationReason,
  ];
}

/// Immutable Mobile contract for one UC-10 itinerary-generation attempt.
final class ItineraryGenerationRequest extends Equatable {
  const ItineraryGenerationRequest({
    required this.startAt,
    required this.timeZoneId,
    required this.startLatitude,
    required this.startLongitude,
    required this.explorationLatitude,
    required this.explorationLongitude,
    required this.returnToStart,
    required this.availableMinutes,
    required this.transportMode,
    required this.searchRadiusKm,
    required this.mandatoryPoiIds,
    required this.restPreference,
    this.endPoiId,
    this.budgetVnd,
  });

  final String startAt;
  final String timeZoneId;
  final double startLatitude;
  final double startLongitude;
  final double explorationLatitude;
  final double explorationLongitude;
  final int? endPoiId;
  final bool returnToStart;
  final int availableMinutes;
  final TransportMode transportMode;
  final double searchRadiusKm;
  final double? budgetVnd;
  final List<int> mandatoryPoiIds;
  final RestPreference restPreference;

  List<int> get normalizedMandatoryPoiIds =>
      List.unmodifiable([...mandatoryPoiIds]..sort());

  Map<String, dynamic> toJson() => {
    'startAt': startAt,
    'timeZoneId': timeZoneId,
    'startLatitude': startLatitude,
    'startLongitude': startLongitude,
    'explorationLatitude': explorationLatitude,
    'explorationLongitude': explorationLongitude,
    'endPoiId': endPoiId,
    'returnToStart': returnToStart,
    'availableMinutes': availableMinutes,
    'transportMode': _transportModeName(transportMode),
    'searchRadiusKm': searchRadiusKm,
    'budgetVnd': budgetVnd,
    'mandatoryPoiIds': normalizedMandatoryPoiIds,
    'restPreference': _restPreferenceName(restPreference),
  };

  @override
  List<Object?> get props => [
    startAt,
    timeZoneId,
    startLatitude,
    startLongitude,
    explorationLatitude,
    explorationLongitude,
    endPoiId,
    returnToStart,
    availableMinutes,
    transportMode,
    searchRadiusKm,
    budgetVnd,
    normalizedMandatoryPoiIds,
    restPreference,
  ];
}

String _transportModeName(TransportMode value) => switch (value) {
  TransportMode.walking => 'Walking',
  TransportMode.motorbike => 'Motorbike',
  TransportMode.car => 'Car',
  TransportMode.publicTransit => 'PublicTransit',
};

String _restPreferenceName(RestPreference value) => switch (value) {
  RestPreference.auto => 'Auto',
  RestPreference.none => 'None',
  RestPreference.frequent => 'Frequent',
};
