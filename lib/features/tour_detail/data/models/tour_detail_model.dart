import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_cancellation_rule.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_day.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_stop.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

/// Strict parser for `GET /api/v1/tours/{tourId}` (UC-26).
///
/// Ids are strings, prices whole VND, timestamps UTC. Anything that does not
/// match the contract throws [FormatException] so the screen shows an error
/// instead of a partly wrong tour.
final class TourDetailModel {
  const TourDetailModel._(this._entity);

  factory TourDetailModel.fromJson(Map<String, Object?> json) {
    final operator = _object(json, 'operator');
    final rating = _object(json, 'rating');
    final ratingCount = _wholeNumber(rating, 'count');
    final average = _optionalDouble(rating, 'average');
    final currency = _nonEmptyString(json, 'currency');
    final images = _list(json, 'images').map(_image).toList();
    final primaryFirst = [
      ...images.where((image) => image.isPrimary),
      ...images.where((image) => !image.isPrimary),
    ];
    final days = _list(json, 'itinerary').map(_day).toList()
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    final rules =
        _list(_object(json, 'cancellationPolicy'), 'rules').map(_rule).toList()
          ..sort((a, b) => b.daysBeforeDeparture - a.daysBeforeDeparture);

    return TourDetailModel._(
      TourDetail(
        tourId: _nonEmptyString(json, 'tourId'),
        title: _string(json, 'title'),
        description: _optionalString(json, 'description') ?? '',
        destinations: _list(json, 'destinations').map(_listString).toList(),
        destinationSummary: _string(json, 'destination'),
        durationDays: _wholeNumber(json, 'durationDays'),
        operatorName: _string(operator, 'name'),
        operatorPhone: _optionalString(operator, 'contactPhone'),
        basePrice: _wholeNumber(json, 'basePrice'),
        currency: currency,
        images: primaryFirst.map((image) => image.url).toList(),
        inclusions: _lines(_optionalString(json, 'inclusions')),
        exclusions: _lines(_optionalString(json, 'exclusions')),
        cancellationPolicy: '',
        cancellationRules: rules,
        itineraryDays: days,
        schedules: _list(
          json,
          'schedules',
        ).map((entry) => _schedule(entry, currency)).toList(),
        hasBookableSchedule: _bool(json, 'hasBookableSchedule'),
        averageRating: ratingCount > 0 ? average : null,
        reviewCount: ratingCount,
        asOfUtc: _utc(json, 'asOfUtc'),
      ),
    );
  }

  final TourDetail _entity;

  TourDetail toEntity() => _entity;
}

typedef _Json = Map<String, Object?>;

final class _Image {
  const _Image(this.url, this.isPrimary);
  final String url;
  final bool isPrimary;
}

_Image _image(Object? entry) {
  final json = _asObject(entry, 'image');
  _string(json, 'altText');
  _optionalString(json, 'caption');
  return _Image(_nonEmptyString(json, 'url'), _bool(json, 'isPrimary'));
}

TourCancellationRule _rule(Object? entry) {
  final json = _asObject(entry, 'cancellation rule');
  final percent = json['cancellationFeePercent'];
  if (percent is! num || !percent.isFinite || percent < 0 || percent > 100) {
    throw const FormatException('Missing or invalid cancellationFeePercent.');
  }
  return TourCancellationRule(
    daysBeforeDeparture: _wholeNumber(json, 'daysBeforeDeparture'),
    feePercent: percent.toDouble(),
  );
}

TourItineraryDay _day(Object? entry) {
  final json = _asObject(entry, 'itinerary day');
  final dayNo = _wholeNumber(json, 'dayNo');
  final stops = _list(json, 'items').map(_stop).toList()
    ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));
  return TourItineraryDay(
    dayNumber: dayNo,
    title: 'Day $dayNo',
    description: '',
    stops: stops.map((stop) => stop.stop).toList(),
  );
}

final class _OrderedStop {
  const _OrderedStop(this.sequenceNo, this.stop);
  final int sequenceNo;
  final TourItineraryStop stop;
}

_OrderedStop _stop(Object? entry) {
  final json = _asObject(entry, 'itinerary item');
  final poi = _object(json, 'poi');
  _nonEmptyString(poi, 'poiId');
  return _OrderedStop(
    _wholeNumber(json, 'sequenceNo'),
    TourItineraryStop(
      poiName: _string(poi, 'name'),
      address: _optionalString(poi, 'address'),
      plannedTime: _clock(_optionalString(json, 'plannedTime')),
      stayMinutes: _wholeNumber(json, 'stayDurationMinutes'),
      notes: _optionalString(json, 'notes'),
    ),
  );
}

TourScheduleItem _schedule(Object? entry, String currency) {
  final json = _asObject(entry, 'schedule');
  return TourScheduleItem(
    scheduleId: _nonEmptyString(json, 'scheduleId'),
    departureAtUtc: _utc(json, 'startAtUtc'),
    endAtUtc: _utc(json, 'endAtUtc'),
    meetingPoint: _optionalString(json, 'meetingPoint'),
    registrationDeadlineUtc: _optionalUtc(json, 'registrationDeadlineAtUtc'),
    price: _wholeNumber(json, 'adultPrice'),
    childPrice: _optionalWholeNumber(json, 'childPrice'),
    infantPrice: _optionalWholeNumber(json, 'infantPrice'),
    currency: currency,
    remainingSlots: _optionalWholeNumber(json, 'remainingSlots'),
    availabilityStatus: _availability(json),
    bookable: _bool(json, 'bookable'),
  );
}

AvailabilityStatus _availability(_Json json) {
  return switch (json['availabilityStatus']) {
    'available' => AvailabilityStatus.available,
    'soldOut' => AvailabilityStatus.soldOut,
    'unknown' => AvailabilityStatus.unknown,
    _ => throw const FormatException('Missing or invalid availabilityStatus.'),
  };
}

final _zoned = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

DateTime? _optionalUtc(_Json json, String key) {
  if (json[key] == null) return null;
  return _utc(json, key);
}

DateTime _utc(_Json json, String key) {
  final value = json[key];
  if (value is String && _zoned.hasMatch(value)) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  throw FormatException('Missing or invalid $key.');
}

final _clockPattern = RegExp(r'^(\d{2}:\d{2})(:\d{2}(\.\d+)?)?$');

String? _clock(String? value) {
  if (value == null) return null;
  final match = _clockPattern.firstMatch(value);
  return match == null ? value : match.group(1);
}

final _bullet = RegExp('^[-•*]\\s*');

List<String> _lines(String? value) {
  if (value == null) return const [];
  return value
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim().replaceFirst(_bullet, '').trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

_Json _asObject(Object? value, String what) {
  if (value is Map<Object?, Object?>) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  throw FormatException('Invalid $what.');
}

_Json _object(_Json json, String key) => _asObject(json[key], key);

List<Object?> _list(_Json json, String key) {
  final value = json[key];
  if (value is List<Object?>) return value;
  throw FormatException('$key must be a list.');
}

String _listString(Object? value) {
  if (value is String) return value;
  throw const FormatException('List entries must be strings.');
}

String _string(_Json json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Missing or invalid $key.');
}

String _nonEmptyString(_Json json, String key) {
  final value = _string(json, key);
  if (value.trim().isEmpty) throw FormatException('Missing or invalid $key.');
  return value;
}

String? _optionalString(_Json json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Invalid $key.');
}

bool _bool(_Json json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Missing or invalid $key.');
}

int _wholeNumber(_Json json, String key) {
  final value = json[key];
  if (value is num && value.isFinite && value >= 0 && value == value.floor()) {
    return value.toInt();
  }
  throw FormatException('Missing or invalid $key.');
}

int? _optionalWholeNumber(_Json json, String key) {
  if (json[key] == null) return null;
  return _wholeNumber(json, key);
}

double? _optionalDouble(_Json json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Invalid $key.');
}
