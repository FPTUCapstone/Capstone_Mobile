import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/models/tour_detail_model.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

Map<String, Object?> _schedule({
  String id = '501',
  Object? startAtUtc = '2026-11-06T01:00:00Z',
  Object? endAtUtc = '2026-11-08T10:00:00Z',
  Object? meetingPoint = 'Sảnh khách sạn Mường Thanh, Đà Nẵng',
  Object? registrationDeadlineAtUtc = '2026-11-05T17:00:00Z',
  Object? adultPrice = 2890000,
  Object? childPrice = 900000,
  Object? infantPrice = 0,
  Object? remainingSlots = 8,
  Object? availabilityStatus = 'available',
  Object? bookable = true,
}) => {
  'scheduleId': id,
  'startAtUtc': startAtUtc,
  'endAtUtc': endAtUtc,
  'meetingPoint': meetingPoint,
  'registrationDeadlineAtUtc': registrationDeadlineAtUtc,
  'adultPrice': adultPrice,
  'childPrice': childPrice,
  'infantPrice': infantPrice,
  'remainingSlots': remainingSlots,
  'availabilityStatus': availabilityStatus,
  'bookable': bookable,
};

Map<String, Object?> _payload({
  Map<String, Object?> Function(Map<String, Object?> json)? tweak,
}) {
  final json = <String, Object?>{
    'tourId': '9007199254740993',
    'title': 'Da Nang Discovery 3D2N',
    'description': 'Explore Da Nang.',
    'destination': 'Da Nang, Hoi An',
    'destinations': ['Da Nang', 'Hoi An'],
    'durationDays': 3,
    'basePrice': 2890000,
    'currency': 'VND',
    'operator': {'name': 'Central Vietnam Travel', 'contactPhone': '1900 1808'},
    'images': [
      {
        'url': 'https://cdn.example.test/b.jpg',
        'altText': 'Beach',
        'caption': null,
        'isPrimary': false,
      },
      {
        'url': 'https://cdn.example.test/a.jpg',
        'altText': 'Bridge',
        'caption': 'Dragon Bridge',
        'isPrimary': true,
      },
    ],
    'inclusions': '- Hotel\n• Guide\n\n* Tickets',
    'exclusions': 'Flights',
    'cancellationPolicy': {
      'rules': [
        {'daysBeforeDeparture': 7, 'cancellationFeePercent': 50},
        {'daysBeforeDeparture': 30, 'cancellationFeePercent': 0},
        {'daysBeforeDeparture': 15, 'cancellationFeePercent': 25.5},
      ],
    },
    'itinerary': [
      {
        'dayNo': 1,
        'items': [
          {
            'sequenceNo': 2,
            'poi': {
              'poiId': '12',
              'name': 'Dragon Bridge',
              'address': null,
              'latitude': 16.06,
              'longitude': 108.22,
            },
            'plannedTime': null,
            'stayDurationMinutes': 30,
            'notes': null,
          },
          {
            'sequenceNo': 1,
            'poi': {
              'poiId': '11',
              'name': 'Marble Mountains',
              'address': '81 Huyen Tran Cong Chua',
              'latitude': 16,
              'longitude': 108,
            },
            'plannedTime': '08:30:00',
            'stayDurationMinutes': 90,
            'notes': 'Wear comfortable shoes',
          },
        ],
      },
    ],
    'schedules': [_schedule()],
    'hasBookableSchedule': true,
    'rating': {'average': 4.5, 'count': 12},
    'asOfUtc': '2026-10-17T09:00:00Z',
  };
  return tweak == null ? json : tweak(json);
}

void _expectRejected(Map<String, Object?> json) {
  expect(() => TourDetailModel.fromJson(json), throwsA(isA<FormatException>()));
}

void main() {
  group('TourDetailModel.fromJson valid payload', () {
    test('maps the whole contract to the entity', () {
      final detail = TourDetailModel.fromJson(_payload()).toEntity();

      expect(detail.tourId, '9007199254740993');
      expect(detail.title, 'Da Nang Discovery 3D2N');
      expect(detail.description, 'Explore Da Nang.');
      expect(detail.destinations, ['Da Nang', 'Hoi An']);
      expect(detail.destinationSummary, 'Da Nang, Hoi An');
      expect(detail.durationDays, 3);
      expect(detail.operatorName, 'Central Vietnam Travel');
      expect(detail.operatorPhone, '1900 1808');
      expect(detail.operatorEmail, isNull);
      expect(detail.basePrice, 2890000);
      expect(detail.currency, 'VND');
      expect(detail.hasBookableSchedule, isTrue);
      expect(detail.averageRating, 4.5);
      expect(detail.reviewCount, 12);
      expect(detail.reviews, isEmpty);
      expect(detail.asOfUtc, DateTime.utc(2026, 10, 17, 9));
    });

    test('puts the primary image first and keeps the rest in order', () {
      final detail = TourDetailModel.fromJson(_payload()).toEntity();

      expect(detail.images, [
        'https://cdn.example.test/a.jpg',
        'https://cdn.example.test/b.jpg',
      ]);
    });

    test('splits inclusions and exclusions into clean lines', () {
      final detail = TourDetailModel.fromJson(_payload()).toEntity();

      expect(detail.inclusions, ['Hotel', 'Guide', 'Tickets']);
      expect(detail.exclusions, ['Flights']);
    });

    test('orders cancellation rules from the longest notice down', () {
      final rules = TourDetailModel.fromJson(
        _payload(),
      ).toEntity().cancellationRules;

      expect(rules.map((rule) => rule.daysBeforeDeparture), [30, 15, 7]);
      expect(rules.map((rule) => rule.feePercent), [0, 25.5, 50]);
    });

    test('orders stops by sequence and normalises the planned time', () {
      final day = TourDetailModel.fromJson(
        _payload(),
      ).toEntity().itineraryDays.single;

      expect(day.dayNumber, 1);
      expect(day.title, 'Day 1');
      expect(day.stops.map((stop) => stop.poiName), [
        'Marble Mountains',
        'Dragon Bridge',
      ]);
      final first = day.stops.first;
      expect(first.plannedTime, '08:30');
      expect(first.address, '81 Huyen Tran Cong Chua');
      expect(first.stayMinutes, 90);
      expect(first.notes, 'Wear comfortable shoes');
      expect(day.stops.last.plannedTime, isNull);
      expect(day.stops.last.address, isNull);
      expect(day.stops.last.notes, isNull);
    });

    test('maps a schedule with every detail', () {
      final schedule = TourDetailModel.fromJson(
        _payload(),
      ).toEntity().schedules.single;

      expect(schedule.scheduleId, '501');
      expect(schedule.departureAtUtc, DateTime.utc(2026, 11, 6, 1));
      expect(schedule.endAtUtc, DateTime.utc(2026, 11, 8, 10));
      expect(schedule.meetingPoint, 'Sảnh khách sạn Mường Thanh, Đà Nẵng');
      expect(schedule.registrationDeadlineUtc, DateTime.utc(2026, 11, 5, 17));
      expect(schedule.price, 2890000);
      expect(schedule.childPrice, 900000);
      expect(schedule.infantPrice, 0);
      expect(schedule.currency, 'VND');
      expect(schedule.remainingSlots, 8);
      expect(schedule.totalSlots, isNull);
      expect(schedule.availabilityStatus, AvailabilityStatus.available);
      expect(schedule.bookable, isTrue);
    });

    test('converts offset timestamps to UTC', () {
      final schedule = TourDetailModel.fromJson(
        _payload(
          tweak: (json) => json
            ..['schedules'] = [
              _schedule(startAtUtc: '2026-11-06T08:00:00+07:00'),
            ],
        ),
      ).toEntity().schedules.single;

      expect(schedule.departureAtUtc, DateTime.utc(2026, 11, 6, 1));
      expect(schedule.departureAtUtc.isUtc, isTrue);
    });

    test('maps sold out, unknown and closed departures', () {
      final schedules = TourDetailModel.fromJson(
        _payload(
          tweak: (json) => json
            ..['schedules'] = [
              _schedule(
                id: '1',
                remainingSlots: 0,
                availabilityStatus: 'soldOut',
                bookable: false,
              ),
              _schedule(
                id: '2',
                remainingSlots: null,
                availabilityStatus: 'unknown',
                bookable: false,
              ),
              _schedule(id: '3', bookable: false),
            ],
        ),
      ).toEntity().schedules;

      expect(schedules[0].availabilityStatus, AvailabilityStatus.soldOut);
      expect(schedules[0].isSoldOut, isTrue);
      expect(schedules[1].availabilityStatus, AvailabilityStatus.unknown);
      expect(schedules[1].remainingSlots, isNull);
      expect(schedules[1].isSoldOut, isFalse);
      expect(schedules[2].bookable, isFalse);
    });

    test('accepts a tour with no optional content', () {
      final detail = TourDetailModel.fromJson(
        _payload(
          tweak: (json) => json
            ..['description'] = null
            ..['inclusions'] = null
            ..['exclusions'] = null
            ..['images'] = <Object?>[]
            ..['itinerary'] = <Object?>[]
            ..['schedules'] = <Object?>[]
            ..['hasBookableSchedule'] = false
            ..['operator'] = {'name': 'Op'}
            ..['cancellationPolicy'] = {'rules': <Object?>[]}
            ..['rating'] = {'average': null, 'count': 0},
        ),
      ).toEntity();

      expect(detail.description, isEmpty);
      expect(detail.inclusions, isEmpty);
      expect(detail.exclusions, isEmpty);
      expect(detail.images, isEmpty);
      expect(detail.itineraryDays, isEmpty);
      expect(detail.schedules, isEmpty);
      expect(detail.hasBookableSchedule, isFalse);
      expect(detail.operatorPhone, isNull);
      expect(detail.cancellationRules, isEmpty);
      expect(detail.averageRating, isNull);
      expect(detail.reviewCount, 0);
    });

    test('omitted optional schedule fields read as null', () {
      final schedule = TourDetailModel.fromJson(
        _payload(
          tweak: (json) => json
            ..['schedules'] = [
              {
                'scheduleId': '9',
                'startAtUtc': '2026-11-06T01:00:00Z',
                'endAtUtc': '2026-11-08T10:00:00Z',
                'adultPrice': 1000000,
                'availabilityStatus': 'unknown',
                'bookable': false,
              },
            ],
        ),
      ).toEntity().schedules.single;

      expect(schedule.meetingPoint, isNull);
      expect(schedule.registrationDeadlineUtc, isNull);
      expect(schedule.childPrice, isNull);
      expect(schedule.infantPrice, isNull);
      expect(schedule.remainingSlots, isNull);
    });

    test('hides the average when nobody has reviewed the tour', () {
      final detail = TourDetailModel.fromJson(
        _payload(
          tweak: (json) => json..['rating'] = {'average': 4.0, 'count': 0},
        ),
      ).toEntity();

      expect(detail.averageRating, isNull);
      expect(detail.reviewCount, 0);
    });
  });

  group('TourDetailModel.fromJson rejects', () {
    for (final key in const [
      'tourId',
      'title',
      'destination',
      'destinations',
      'durationDays',
      'basePrice',
      'currency',
      'operator',
      'images',
      'cancellationPolicy',
      'itinerary',
      'schedules',
      'hasBookableSchedule',
      'rating',
      'asOfUtc',
    ]) {
      test('a payload without $key', () {
        _expectRejected(_payload(tweak: (json) => json..remove(key)));
      });
    }

    test('numeric ids', () {
      _expectRejected(_payload(tweak: (json) => json..['tourId'] = 12));
      _expectRejected(
        _payload(
          tweak: (json) =>
              json..['schedules'] = [_schedule(id: '1')..['scheduleId'] = 1],
        ),
      );
    });

    test('an empty tour id', () {
      _expectRejected(_payload(tweak: (json) => json..['tourId'] = ''));
    });

    test('a non-object root or operator', () {
      _expectRejected(_payload(tweak: (json) => json..['operator'] = 'x'));
      _expectRejected(
        _payload(tweak: (json) => json..['rating'] = <Object?>[]),
      );
    });

    test('collections that are not lists', () {
      for (final key in const [
        'destinations',
        'images',
        'itinerary',
        'schedules',
      ]) {
        _expectRejected(_payload(tweak: (json) => json..[key] = 'x'));
        _expectRejected(_payload(tweak: (json) => json..[key] = {'a': 1}));
      }
      _expectRejected(
        _payload(
          tweak: (json) => json..['cancellationPolicy'] = {'rules': 'x'},
        ),
      );
    });

    test('a non-string entry in destinations', () {
      _expectRejected(
        _payload(tweak: (json) => json..['destinations'] = ['Da Nang', 3]),
      );
    });

    test('wrong scalar types', () {
      _expectRejected(_payload(tweak: (json) => json..['title'] = 5));
      _expectRejected(_payload(tweak: (json) => json..['durationDays'] = '3'));
      _expectRejected(_payload(tweak: (json) => json..['basePrice'] = '100'));
      _expectRejected(_payload(tweak: (json) => json..['currency'] = null));
      _expectRejected(
        _payload(tweak: (json) => json..['hasBookableSchedule'] = 'yes'),
      );
      _expectRejected(_payload(tweak: (json) => json..['description'] = 7));
    });

    test('fractional or negative whole numbers', () {
      _expectRejected(_payload(tweak: (json) => json..['durationDays'] = 2.5));
      _expectRejected(_payload(tweak: (json) => json..['basePrice'] = 100.5));
      _expectRejected(_payload(tweak: (json) => json..['basePrice'] = -1));
      _expectRejected(
        _payload(
          tweak: (json) => json..['rating'] = {'average': 4.0, 'count': -1},
        ),
      );
      _expectRejected(
        _payload(
          tweak: (json) => json..['schedules'] = [_schedule(adultPrice: 10.5)],
        ),
      );
      _expectRejected(
        _payload(
          tweak: (json) =>
              json..['schedules'] = [_schedule(remainingSlots: -1)],
        ),
      );
    });

    test('an availability status outside the closed set', () {
      for (final status in <Object?>['AVAILABLE', 'full', '', null, 1]) {
        _expectRejected(
          _payload(
            tweak: (json) =>
                json..['schedules'] = [_schedule(availabilityStatus: status)],
          ),
        );
      }
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['schedules'] = [
              _schedule(availabilityStatus: 'noUpcomingSchedule'),
            ],
        ),
      );
    });

    test('a schedule without a boolean bookable flag', () {
      _expectRejected(
        _payload(
          tweak: (json) => json..['schedules'] = [_schedule(bookable: 'true')],
        ),
      );
      _expectRejected(
        _payload(
          tweak: (json) => json..['schedules'] = [_schedule(bookable: null)],
        ),
      );
    });

    test('unparseable or zone-less timestamps', () {
      for (final bad in <Object?>['not a date', '', '2026-11-06T01:00:00', 5]) {
        _expectRejected(
          _payload(
            tweak: (json) => json..['schedules'] = [_schedule(startAtUtc: bad)],
          ),
        );
        _expectRejected(
          _payload(
            tweak: (json) => json..['schedules'] = [_schedule(endAtUtc: bad)],
          ),
        );
      }
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['schedules'] = [_schedule(registrationDeadlineAtUtc: 'soon')],
        ),
      );
      _expectRejected(_payload(tweak: (json) => json..['asOfUtc'] = 'now'));
    });

    test('malformed images', () {
      _expectRejected(
        _payload(tweak: (json) => json..['images'] = ['https://x.test/a.jpg']),
      );
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['images'] = [
              {'url': '', 'altText': '', 'isPrimary': false},
            ],
        ),
      );
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['images'] = [
              {'url': 'https://x.test/a.jpg', 'altText': '', 'isPrimary': 1},
            ],
        ),
      );
    });

    test('malformed itinerary entries', () {
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['itinerary'] = [
              {'dayNo': '1', 'items': <Object?>[]},
            ],
        ),
      );
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['itinerary'] = [
              {'dayNo': 1, 'items': 'x'},
            ],
        ),
      );
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['itinerary'] = [
              {
                'dayNo': 1,
                'items': [
                  {
                    'sequenceNo': 1,
                    'poi': {'poiId': 11, 'name': 'x'},
                    'stayDurationMinutes': 10,
                  },
                ],
              },
            ],
        ),
      );
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['itinerary'] = [
              {
                'dayNo': 1,
                'items': [
                  {
                    'sequenceNo': 1,
                    'poi': {'poiId': '11', 'name': 'x'},
                    'stayDurationMinutes': 'long',
                  },
                ],
              },
            ],
        ),
      );
    });

    test('malformed cancellation rules', () {
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['cancellationPolicy'] = {
              'rules': [
                {'daysBeforeDeparture': '7', 'cancellationFeePercent': 10},
              ],
            },
        ),
      );
      _expectRejected(
        _payload(
          tweak: (json) => json
            ..['cancellationPolicy'] = {
              'rules': [
                {'daysBeforeDeparture': 7, 'cancellationFeePercent': 101},
              ],
            },
        ),
      );
    });
  });
}
