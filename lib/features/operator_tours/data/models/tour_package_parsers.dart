import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';

/// Strict JSON parsing for the operator tour API. A malformed payload is a [FormatException],
/// never a half-filled entity, so the UI cannot show invented data.

List<Map<String, Object?>> _objects(Object? payload, String label) {
  if (payload is! List) throw FormatException('$label must be a list.');
  return payload
      .map((value) {
        if (value is! Map) throw FormatException('$label item is invalid.');
        return Map<String, Object?>.from(value);
      })
      .toList(growable: false);
}

Map<String, Object?> _object(Object? payload, String label) {
  if (payload is! Map) throw FormatException('$label must be an object.');
  return Map<String, Object?>.from(payload);
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key is missing.');
  return value.toInt();
}

num _num(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key is missing.');
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key is missing.');
  return value;
}

String? _optString(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String && value.trim().isNotEmpty ? value : null;
}

DateTime _date(Map<String, Object?> json, String key) {
  final parsed = DateTime.tryParse(_string(json, key));
  if (parsed == null) throw FormatException('$key is not a date.');
  return parsed.toUtc();
}

DateTime? _optDate(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

TourPackageStatus _status(Map<String, Object?> json) {
  final status = TourPackageStatus.tryParse(_string(json, 'status'));
  if (status == null) {
    throw FormatException('Unsupported tour status: ${json['status']}.');
  }
  return status;
}

TourPackageOptions parseTourPackageOptions(
  Object? destinations,
  Object? policies, [
  Object? categories,
]) {
  return TourPackageOptions(
    destinations: _objects(destinations, 'Destination response')
        .map((item) {
          final id = _int(item, 'destinationId');
          final name = _string(item, 'name').trim();
          if (id <= 0 || name.isEmpty) {
            throw const FormatException('Destination item is invalid.');
          }
          return TourDestinationOption(id: id, name: name);
        })
        .toList(growable: false),
    policies: _objects(policies, 'Cancellation policy response')
        .map((item) {
          final id = _int(item, 'id');
          final name = _string(item, 'name').trim();
          if (id <= 0 || name.isEmpty) {
            throw const FormatException('Cancellation policy item is invalid.');
          }
          return CancellationPolicyOption(
            id: id,
            name: name,
            description: _optString(item, 'description')?.trim(),
          );
        })
        .toList(growable: false),
    categories: categories == null
        ? const []
        : _objects(categories, 'Category response')
              .map((item) {
                final id = _int(item, 'categoryId');
                final name = _string(item, 'name').trim();
                if (id <= 0 || name.isEmpty) {
                  throw const FormatException('Category item is invalid.');
                }
                return TourCategoryOption(
                  id: id,
                  code: _optString(item, 'code')?.trim() ?? '',
                  name: name,
                );
              })
              .toList(growable: false),
  );
}

TourPackagePage parseTourPackagePage(Object? payload) {
  final json = _object(payload, 'Tour list response');
  return TourPackagePage(
    page: _int(json, 'page'),
    totalCount: _int(json, 'totalCount'),
    items: _objects(json['items'], 'Tour list')
        .map((item) {
          return TourPackageSummary(
            id: _int(item, 'id'),
            title: _string(item, 'title'),
            status: _status(item),
            basePrice: _num(item, 'basePrice'),
            durationDays: _int(item, 'durationDays'),
            destination: _optString(item, 'destination') ?? '',
            nextDepartureAtUtc: _optDate(item, 'nextDepartureAtUtc'),
            versionNo: item['versionNo'] is num
                ? (item['versionNo']! as num).toInt()
                : 1,
            publishedAtUtc: _optDate(item, 'publishedAtUtc'),
            upcomingDepartureCount: item['upcomingDepartureCount'] is num
                ? (item['upcomingDepartureCount']! as num).toInt()
                : null,
            completedDepartureCount: item['completedDepartureCount'] is num
                ? (item['completedDepartureCount']! as num).toInt()
                : null,
            totalDepartureCount: item['totalDepartureCount'] is num
                ? (item['totalDepartureCount']! as num).toInt()
                : null,
          );
        })
        .toList(growable: false),
  );
}

TourPackageDetail parseTourPackageDetail(Object? payload) {
  final json = _object(payload, 'Tour response');
  final destinations = _objects(json['destinations'], 'Destinations');
  return TourPackageDetail(
    id: _int(json, 'id'),
    title: _string(json, 'title'),
    description: _string(json, 'description'),
    status: _status(json),
    basePrice: _num(json, 'basePrice'),
    durationDays: _int(json, 'durationDays'),
    categoryId: json['categoryId'] is num
        ? (json['categoryId']! as num).toInt()
        : null,
    rejectionReason: _optString(json, 'rejectionReason'),
    submissionNote: _optString(json, 'submissionNote'),
    submittedAtUtc: _optDate(json, 'submittedAtUtc'),
    inclusions: _optString(json, 'inclusions'),
    exclusions: _optString(json, 'exclusions'),
    highlights: _optString(json, 'highlights'),
    travellerRequirements: _optString(json, 'travellerRequirements'),
    timeZoneId: _optString(json, 'timeZoneId'),
    destinationIds: [
      for (final item in destinations) _int(item, 'destinationId'),
    ],
    destinationNames: [for (final item in destinations) _string(item, 'name')],
    cancellationPolicyTemplateId: json['cancellationPolicyTemplateId'] is num
        ? (json['cancellationPolicyTemplateId']! as num).toInt()
        : null,
    cancellationFeeRules: [
      for (final rule in _objects(
        json['cancellationPolicyRules'],
        'Cancellation rules',
      ))
        (
          _int(rule, 'daysBeforeDeparture'),
          _num(rule, 'cancellationFeePercent'),
        ),
    ],
    itineraryItems: _objects(json['itineraryItems'], 'Itinerary')
        .map((item) {
          return TourItineraryItemDetail(
            dayNo: _int(item, 'dayNo'),
            sequenceNo: _int(item, 'sequenceNo'),
            poiId: _int(item, 'poiId'),
            stayDurationMinutes: _int(item, 'stayDurationMinutes'),
            plannedTime: _optString(item, 'plannedTime'),
            notes: _optString(item, 'notes'),
          );
        })
        .toList(growable: false),
    departures: _objects(json['departures'], 'Departures')
        .map((item) {
          return TourDepartureDetail(
            id: item['id'] is num ? (item['id']! as num).toInt() : null,
            status: _optString(item, 'status'),
            startAtUtc: _date(item, 'startAtUtc'),
            endAtUtc: _date(item, 'endAtUtc'),
            minimumCapacity: _int(item, 'minimumCapacity'),
            totalCapacity: _int(item, 'totalCapacity'),
            reservedCapacity: _int(item, 'reservedCapacity'),
            meetingPoint: _optString(item, 'meetingPoint'),
            registrationDeadlineAtUtc: _optDate(
              item,
              'registrationDeadlineAtUtc',
            ),
            adultPrice: item['adultPrice'] is num
                ? item['adultPrice']! as num
                : null,
            childPrice: item['childPrice'] is num
                ? item['childPrice']! as num
                : null,
            infantPrice: item['infantPrice'] is num
                ? item['infantPrice']! as num
                : null,
            meetingLatitude: item['meetingLatitude'] is num
                ? (item['meetingLatitude']! as num).toDouble()
                : null,
            meetingLongitude: item['meetingLongitude'] is num
                ? (item['meetingLongitude']! as num).toDouble()
                : null,
            isCompleted: item['isCompleted'] == true,
          );
        })
        .toList(growable: false),
    versionNo: json['versionNo'] is num
        ? (json['versionNo']! as num).toInt()
        : 1,
    publishedAtUtc: _optDate(json, 'publishedAtUtc'),
    allowDeposit: json['allowDeposit'] == true,
    depositPercent: json['depositPercent'] is num
        ? json['depositPercent']! as num
        : null,
    balanceDueDaysBeforeDeparture: json['balanceDueDaysBeforeDeparture'] is num
        ? (json['balanceDueDaysBeforeDeparture']! as num).toInt()
        : null,
    versions: json['versions'] == null
        ? const []
        : _objects(json['versions'], 'Versions')
              .map(
                (item) => TourVersionHistoryItem(
                  tourId: _int(item, 'tourId'),
                  versionNo: _int(item, 'versionNo'),
                  status: _status(item),
                  createdAtUtc: _optDate(item, 'createdAtUtc'),
                  publishedAtUtc: _optDate(item, 'publishedAtUtc'),
                  rejectionReason: _optString(item, 'rejectionReason'),
                ),
              )
              .toList(growable: false),
    reviewBlockers: [
      for (final code in (json['reviewBlockers'] as List? ?? const []))
        if (code is String) code,
    ],
    warnings: _objects(json['warnings'] ?? const [], 'Warnings')
        .map((item) {
          return TourWarning(
            code: _string(item, 'code'),
            dayNo: item['dayNo'] is num
                ? (item['dayNo']! as num).toInt()
                : null,
            sequenceNo: item['sequenceNo'] is num
                ? (item['sequenceNo']! as num).toInt()
                : null,
            poiId: item['poiId'] is num
                ? (item['poiId']! as num).toInt()
                : null,
          );
        })
        .toList(growable: false),
    canSubmitForReview: json['canSubmitForReview'] == true,
    hasPrimaryImage: json['hasPrimaryImage'] == true,
    mediaCount: json['mediaCount'] is num
        ? (json['mediaCount']! as num).toInt()
        : 0,
  );
}

List<TourMediaItem> parseTourMediaList(Object? payload) {
  final items = _objects(payload, 'Media response').map((item) {
    return (
      sortOrder: item['sortOrder'] is num ? (item['sortOrder']! as num) : 0,
      media: TourMediaItem(
        id: _int(item, 'tourMediaId'),
        url: _string(item, 'deliveryUrl'),
        isPrimary: item['isPrimary'] == true,
        altText: _optString(item, 'altText'),
      ),
    );
  }).toList();
  items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return [for (final item in items) item.media];
}

TourReviewSubmission parseTourReviewSubmission(Object? payload, int tourId) {
  final json = _object(payload, 'Submission response');
  if (_int(json, 'tourId') != tourId || _string(json, 'status') != 'Pending') {
    throw const FormatException('Unexpected submission response.');
  }
  return TourReviewSubmission(
    tourId: tourId,
    submittedAtUtc: _optDate(json, 'submittedAtUtc'),
  );
}

TourDepartureDetail parseAddedDeparture(Object? payload) {
  final json = _object(payload, 'Add departure response');
  return TourDepartureDetail(
    id: _int(json, 'scheduleId'),
    status: _optString(json, 'status') ?? 'Scheduled',
    startAtUtc: _date(json, 'startAtUtc'),
    endAtUtc: _date(json, 'endAtUtc'),
    minimumCapacity: _int(json, 'minimumCapacity'),
    totalCapacity: _int(json, 'totalCapacity'),
    reservedCapacity: _int(json, 'reservedCapacity'),
    meetingPoint: _optString(json, 'meetingPoint'),
    registrationDeadlineAtUtc: _optDate(json, 'registrationDeadlineAtUtc'),
    adultPrice: json['adultPrice'] is num ? json['adultPrice']! as num : null,
    childPrice: json['childPrice'] is num ? json['childPrice']! as num : null,
    infantPrice: json['infantPrice'] is num
        ? json['infantPrice']! as num
        : null,
    meetingLatitude: json['meetingLatitude'] is num
        ? (json['meetingLatitude']! as num).toDouble()
        : null,
    meetingLongitude: json['meetingLongitude'] is num
        ? (json['meetingLongitude']! as num).toDouble()
        : null,
  );
}
