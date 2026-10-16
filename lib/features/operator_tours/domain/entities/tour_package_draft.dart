final class TourItineraryStopDraft {
  const TourItineraryStopDraft({
    required this.poiId,
    required this.dayNo,
    required this.sequenceNo,
    required this.stayDurationMinutes,
    this.plannedTime,
    this.notes,
  });
  final int poiId;
  final int dayNo;
  final int sequenceNo;
  final int stayDurationMinutes;
  final String? plannedTime;
  final String? notes;

  Map<String, Object?> toJson() => {
    'poiId': poiId,
    'dayNo': dayNo,
    'sequenceNo': sequenceNo,
    'stayDurationMinutes': stayDurationMinutes,
    'plannedTime': plannedTime,
    'notes': notes,
  };
}

final class TourScheduleDraft {
  const TourScheduleDraft({
    required this.startAtUtc,
    required this.endAtUtc,
    required this.totalCapacity,
    this.minimumCapacity = 1,
    this.registrationDeadlineAtUtc,
    this.adultPrice,
    this.childPrice,
    this.infantPrice,
    this.meetingPoint,
  });
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final int totalCapacity;
  final int minimumCapacity;
  final DateTime? registrationDeadlineAtUtc;
  final num? adultPrice;
  final num? childPrice;
  final num? infantPrice;
  final String? meetingPoint;

  Map<String, Object?> toJson() => {
    'startAtUtc': startAtUtc.toUtc().toIso8601String(),
    'endAtUtc': endAtUtc.toUtc().toIso8601String(),
    'totalCapacity': totalCapacity,
    'minimumCapacity': minimumCapacity,
    'registrationDeadlineAtUtc': registrationDeadlineAtUtc
        ?.toUtc()
        .toIso8601String(),
    'adultPrice': adultPrice,
    'childPrice': childPrice,
    'infantPrice': infantPrice,
    'meetingPoint': (meetingPoint?.trim().isEmpty ?? true)
        ? null
        : meetingPoint!.trim(),
  };
}

final class TourPackageDraft {
  const TourPackageDraft({
    required this.title,
    required this.description,
    required this.basePrice,
    required this.durationDays,
    required this.destinationIds,
    required this.cancellationPolicyTemplateId,
    required this.itineraryItems,
    required this.schedules,
    this.categoryId,
    this.inclusions,
    this.exclusions,
    this.highlights,
    this.travellerRequirements,
    this.timeZoneId,
  });
  final String title;
  final String description;
  final num basePrice;
  final int durationDays;
  final int? categoryId;
  final String? inclusions;
  final String? exclusions;
  final String? highlights;
  final String? travellerRequirements;

  /// Preserved from the loaded package; the backend defaults it when null.
  final String? timeZoneId;

  /// Catalogue destinations in display order (1-10, unique).
  final List<int> destinationIds;

  /// The backend snapshots this policy's rules onto the package (BR-101).
  final int cancellationPolicyTemplateId;
  final List<TourItineraryStopDraft> itineraryItems;
  final List<TourScheduleDraft> schedules;

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'basePrice': basePrice,
    'durationDays': durationDays,
    'categoryId': categoryId,
    'inclusions': _blankToNull(inclusions),
    'exclusions': _blankToNull(exclusions),
    'highlights': _blankToNull(highlights),
    'travellerRequirements': _blankToNull(travellerRequirements),
    'timeZoneId': timeZoneId,
    'destinationIds': destinationIds,
    'cancellationPolicyTemplateId': cancellationPolicyTemplateId,
    'itineraryItems': itineraryItems.map((item) => item.toJson()).toList(),
    'schedules': schedules.map((item) => item.toJson()).toList(),
  };
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
