import 'package:equatable/equatable.dart';

/// Lifecycle states of a tour package as the backend reports them.
enum TourPackageStatus {
  draft('Draft'),
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  published('Published'),
  inactive('Inactive');

  const TourPackageStatus(this.apiName);
  final String apiName;

  /// Only Draft and Rejected packages can be edited or sent for review.
  bool get isEditable => this == draft || this == rejected;

  static TourPackageStatus? tryParse(String? value) {
    for (final status in values) {
      if (status.apiName == value) return status;
    }
    return null;
  }
}

final class TourPackageSummary extends Equatable {
  const TourPackageSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.basePrice,
    required this.durationDays,
    required this.destination,
    this.nextDepartureAtUtc,
  });
  final int id;
  final String title;
  final TourPackageStatus status;
  final num basePrice;
  final int durationDays;
  final String destination;
  final DateTime? nextDepartureAtUtc;

  @override
  List<Object?> get props => [
    id,
    title,
    status,
    basePrice,
    durationDays,
    destination,
    nextDepartureAtUtc,
  ];
}

final class TourPackagePage extends Equatable {
  const TourPackagePage({
    required this.items,
    required this.page,
    required this.totalCount,
  });
  final List<TourPackageSummary> items;
  final int page;
  final int totalCount;

  @override
  List<Object?> get props => [items, page, totalCount];
}

final class TourDepartureDetail extends Equatable {
  const TourDepartureDetail({
    required this.startAtUtc,
    required this.endAtUtc,
    required this.minimumCapacity,
    required this.totalCapacity,
    required this.reservedCapacity,
    this.meetingPoint,
    this.registrationDeadlineAtUtc,
    this.adultPrice,
    this.childPrice,
    this.infantPrice,
  });
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final int minimumCapacity;
  final int totalCapacity;
  final int reservedCapacity;
  final String? meetingPoint;
  final DateTime? registrationDeadlineAtUtc;
  final num? adultPrice;
  final num? childPrice;
  final num? infantPrice;

  @override
  List<Object?> get props => [
    startAtUtc,
    endAtUtc,
    minimumCapacity,
    totalCapacity,
    reservedCapacity,
    meetingPoint,
    registrationDeadlineAtUtc,
    adultPrice,
    childPrice,
    infantPrice,
  ];
}

final class TourItineraryItemDetail extends Equatable {
  const TourItineraryItemDetail({
    required this.dayNo,
    required this.sequenceNo,
    required this.poiId,
    required this.stayDurationMinutes,
    this.plannedTime,
    this.notes,
  });
  final int dayNo;
  final int sequenceNo;
  final int poiId;
  final int stayDurationMinutes;
  final String? plannedTime;
  final String? notes;

  @override
  List<Object?> get props => [
    dayNo,
    sequenceNo,
    poiId,
    stayDurationMinutes,
    plannedTime,
    notes,
  ];
}

/// A non-blocking itinerary feasibility warning computed by the server.
final class TourWarning extends Equatable {
  const TourWarning({
    required this.code,
    this.dayNo,
    this.sequenceNo,
    this.poiId,
  });
  final String code;
  final int? dayNo;
  final int? sequenceNo;
  final int? poiId;

  @override
  List<Object?> get props => [code, dayNo, sequenceNo, poiId];
}

final class TourMediaItem extends Equatable {
  const TourMediaItem({
    required this.id,
    required this.url,
    required this.isPrimary,
    this.altText,
  });
  final int id;
  final String url;
  final bool isPrimary;
  final String? altText;

  @override
  List<Object?> get props => [id, url, isPrimary, altText];
}

final class TourPackageDetail extends Equatable {
  const TourPackageDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.basePrice,
    required this.durationDays,
    required this.destinationIds,
    required this.destinationNames,
    required this.itineraryItems,
    required this.departures,
    required this.reviewBlockers,
    required this.warnings,
    required this.canSubmitForReview,
    required this.hasPrimaryImage,
    required this.mediaCount,
    this.categoryId,
    this.rejectionReason,
    this.inclusions,
    this.exclusions,
    this.highlights,
    this.travellerRequirements,
    this.timeZoneId,
    this.cancellationPolicyTemplateId,
    this.cancellationFeeRules = const [],
  });
  final int id;
  final String title;
  final String description;
  final TourPackageStatus status;
  final num basePrice;
  final int durationDays;
  final int? categoryId;
  final String? rejectionReason;
  final String? inclusions;
  final String? exclusions;
  final String? highlights;
  final String? travellerRequirements;
  final String? timeZoneId;
  final List<int> destinationIds;
  final List<String> destinationNames;
  final int? cancellationPolicyTemplateId;

  /// `(daysBeforeDeparture, cancellationFeePercent)` pairs of the snapshotted policy.
  final List<(int, num)> cancellationFeeRules;
  final List<TourItineraryItemDetail> itineraryItems;
  final List<TourDepartureDetail> departures;
  final List<String> reviewBlockers;
  final List<TourWarning> warnings;
  final bool canSubmitForReview;
  final bool hasPrimaryImage;
  final int mediaCount;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    status,
    basePrice,
    durationDays,
    categoryId,
    rejectionReason,
    inclusions,
    exclusions,
    highlights,
    travellerRequirements,
    timeZoneId,
    destinationIds,
    destinationNames,
    cancellationPolicyTemplateId,
    cancellationFeeRules,
    itineraryItems,
    departures,
    reviewBlockers,
    warnings,
    canSubmitForReview,
    hasPrimaryImage,
    mediaCount,
  ];
}

/// An image the operator picked, validated and read into memory.
final class TourImageUpload {
  const TourImageUpload({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });
  final String fileName;
  final String contentType;
  final List<int> bytes;
}
