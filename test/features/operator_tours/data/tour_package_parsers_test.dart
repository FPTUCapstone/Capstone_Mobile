import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/models/tour_package_parsers.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';

Map<String, Object?> _detailJson() => {
  'id': 42,
  'title': 'Tour',
  'destination': 'Da Nang, Hoi An',
  'description': 'Description',
  'categoryId': null,
  'basePrice': 1000000,
  'durationDays': 2,
  'status': 'Rejected',
  'rejectionReason': 'Needs a better description',
  'inclusions': 'Meals',
  'exclusions': null,
  'destinations': [
    {'destinationId': 1, 'name': 'Da Nang'},
    {'destinationId': 2, 'name': 'Hoi An'},
  ],
  'cancellationPolicyTemplateId': 7,
  'cancellationPolicyRules': [
    {'daysBeforeDeparture': 30, 'cancellationFeePercent': 0},
  ],
  'itineraryItems': [
    {
      'dayNo': 1,
      'sequenceNo': 1,
      'poiId': 11,
      'plannedTime': '08:00:00',
      'stayDurationMinutes': 90,
      'notes': null,
    },
  ],
  'departures': [
    {
      'id': 5,
      'startAtUtc': '2027-03-01T01:00:00+00:00',
      'endAtUtc': '2027-03-01T09:00:00+00:00',
      'meetingPoint': 'Hotel',
      'minimumCapacity': 4,
      'totalCapacity': 20,
      'reservedCapacity': 0,
      'registrationDeadlineAtUtc': '2027-02-27T00:00:00+00:00',
      'adultPrice': 1200000,
      'childPrice': null,
      'infantPrice': 100000,
      'status': 'Scheduled',
    },
  ],
  'mediaCount': 0,
  'hasPrimaryImage': false,
  'canSubmitForReview': false,
  'reviewBlockers': ['primary_image_missing'],
  'warnings': [
    {'code': 'outside_opening_hours', 'dayNo': 1, 'sequenceNo': 1, 'poiId': 11},
  ],
  'timeZoneId': 'Asia/Bangkok',
  'highlights': 'Cable car',
  'travellerRequirements': null,
};

void main() {
  test('parses the full detail including readiness, warnings and terms', () {
    final detail = parseTourPackageDetail(_detailJson());

    expect(detail.status, TourPackageStatus.rejected);
    expect(detail.status.isEditable, isTrue);
    expect(detail.rejectionReason, 'Needs a better description');
    expect(detail.destinationIds, [1, 2]);
    expect(detail.destinationNames, ['Da Nang', 'Hoi An']);
    expect(detail.cancellationPolicyTemplateId, 7);
    expect(detail.cancellationFeeRules, [(30, 0)]);
    expect(detail.reviewBlockers, ['primary_image_missing']);
    expect(detail.warnings.single.code, 'outside_opening_hours');
    expect(detail.warnings.single.poiId, 11);
    expect(detail.timeZoneId, 'Asia/Bangkok');
    expect(detail.highlights, 'Cable car');
    expect(detail.travellerRequirements, isNull);
    expect(detail.departures.single.minimumCapacity, 4);
    expect(detail.departures.single.childPrice, isNull);
    expect(detail.departures.single.infantPrice, 100000);
    expect(detail.departures.single.startAtUtc.isUtc, isTrue);
    expect(detail.itineraryItems.single.plannedTime, '08:00:00');
  });

  test('an unknown status is a format error, never an editable Draft', () {
    expect(
      () => parseTourPackageDetail({..._detailJson(), 'status': 'Archived'}),
      throwsFormatException,
    );
  });

  test('a missing required field is a format error', () {
    final json = _detailJson()..remove('title');

    expect(() => parseTourPackageDetail(json), throwsFormatException);
    expect(() => parseTourPackageDetail('not json'), throwsFormatException);
  });

  test('parses a paged list', () {
    final page = parseTourPackagePage({
      'items': [
        {
          'id': 1,
          'title': 'A',
          'status': 'Published',
          'basePrice': 5,
          'durationDays': 1,
          'updatedAtUtc': '2026-10-01T00:00:00Z',
          'nextDepartureAtUtc': null,
          'destination': 'Da Nang',
        },
      ],
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
    });

    expect(page.items.single.status, TourPackageStatus.published);
    expect(page.items.single.destination, 'Da Nang');
    expect(page.totalCount, 1);
    expect(() => parseTourPackagePage([]), throwsFormatException);
  });

  test('orders media by sort order and keeps the primary flag', () {
    final media = parseTourMediaList([
      {
        'tourMediaId': 9,
        'deliveryUrl': 'b',
        'sortOrder': 2,
        'isPrimary': false,
      },
      {
        'tourMediaId': 8,
        'deliveryUrl': 'a',
        'sortOrder': 1,
        'isPrimary': true,
        'altText': 'Cover',
      },
    ]);

    expect(media.map((item) => item.id), [8, 9]);
    expect(media.first.isPrimary, isTrue);
    expect(media.first.altText, 'Cover');
  });

  test('parses destination and policy catalogues', () {
    final options = parseTourPackageOptions(
      [
        {'destinationId': 1, 'name': ' Da Nang '},
      ],
      [
        {'id': 7, 'name': 'Standard', 'description': ' '},
      ],
    );

    expect(options.destinations.single.name, 'Da Nang');
    expect(options.policies.single.description, isNull);
    expect(
      () => parseTourPackageOptions([
        {'destinationId': 0, 'name': 'x'},
      ], []),
      throwsFormatException,
    );
  });
}
