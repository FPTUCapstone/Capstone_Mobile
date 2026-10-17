import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/navigation_session_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/mapbox_directions_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';

Map<String, dynamic> navigationSessionJson({
  String state = 'Exploring',
  String? completionReason,
  int? exploringItemId = 1001,
  int? nextItemId = 1002,
}) => {
  'sessionId': 501,
  'itineraryId': 91,
  'itineraryVersion': 3,
  'state': state,
  'completionReason': completionReason,
  'startedAtUtc': '2026-10-20T01:30:00Z',
  'expiresAtUtc': '2026-10-20T16:00:00Z',
  'endedAtUtc': null,
  'exploringItemId': exploringItemId,
  'nextItemId': nextItemId,
  'items': [
    {
      'itemId': 1001,
      'sequenceNo': 1,
      'poiId': 12,
      'poiName': 'Marble Mountains',
      'latitude': 16.0033,
      'longitude': 108.2635,
      'plannedArrivalUtc': '2026-10-20T02:00:00Z',
      'plannedDepartureUtc': '2026-10-20T03:30:00Z',
      'isMandatory': true,
      'status': 'Reached',
      'reachedAtUtc': '2026-10-20T02:15:00Z',
      'skippedAtUtc': null,
    },
    {
      'itemId': 1002,
      'sequenceNo': 2,
      'poiId': 13,
      'poiName': 'Han Market',
      'latitude': 16,
      'longitude': 108,
      'plannedArrivalUtc': '2026-10-20T04:00:00+07:00',
      'plannedDepartureUtc': '2026-10-20T05:00:00Z',
      'isMandatory': false,
      'status': 'Pending',
      'reachedAtUtc': null,
      'skippedAtUtc': null,
    },
  ],
};

void main() {
  group('NavigationSessionModel stop numbers', () {
    test('stops are numbered without the gaps left by breaks', () {
      final json = navigationSessionJson();
      // A break between the two stops takes sequence number 2.
      ((json['items'] as List)[1] as Map)['sequenceNo'] = 3;

      final session = NavigationSessionModel.fromJson(json);

      expect(session.items.map((item) => item.sequenceNo), [1, 3]);
      expect(session.items.map((item) => item.displayNumber), [1, 2]);
    });
  });

  group('NavigationSessionModel transport mode', () {
    test('reads the planned mode and tolerates missing or unknown ones', () {
      TransportMode? parse(Object? value) => NavigationSessionModel.fromJson({
        ...navigationSessionJson(),
        'transportMode': value,
      }).transportMode;

      expect(parse('Walking'), TransportMode.walking);
      expect(parse('Motorbike'), TransportMode.motorbike);
      expect(parse(null), isNull);
      expect(parse('Hovercraft'), isNull);
      expect(
        NavigationSessionModel.fromJson(navigationSessionJson()).transportMode,
        isNull,
      );
    });

    test('reads each stop\'s leg mode and tolerates older payloads', () {
      final json = navigationSessionJson();
      final items = json['items'] as List;
      (items[0] as Map)['transportModeFromPrevious'] = null;
      (items[1] as Map)['transportModeFromPrevious'] = 'Walking';

      final session = NavigationSessionModel.fromJson(json);
      final older = NavigationSessionModel.fromJson(navigationSessionJson());

      expect(session.items.map((item) => item.transportModeFromPrevious), [
        null,
        TransportMode.walking,
      ]);
      expect(
        older.items.map((item) => item.transportModeFromPrevious),
        everyElement(isNull),
      );
    });

    test('walking trips route on foot, road modes by road', () {
      expect(
        MapboxDirectionsRepositoryImpl.profileFor(TransportMode.walking),
        'mapbox/walking',
      );
      for (final mode in [
        TransportMode.motorbike,
        TransportMode.car,
        TransportMode.publicTransit,
        null,
      ]) {
        expect(
          MapboxDirectionsRepositoryImpl.profileFor(mode),
          'mapbox/driving',
        );
      }
    });
  });

  group('NavigationSessionModel', () {
    test('parses the Backend session representation', () {
      final session = NavigationSessionModel.fromJson(navigationSessionJson());

      expect(session.sessionId, 501);
      expect(session.itineraryId, 91);
      expect(session.itineraryVersion, 3);
      expect(session.state, NavigationSessionState.exploring);
      expect(session.completionReason, isNull);
      expect(session.startedAt, DateTime.utc(2026, 10, 20, 1, 30));
      expect(session.expiresAt, DateTime.utc(2026, 10, 20, 16));
      expect(session.exploringItem?.poiName, 'Marble Mountains');
      expect(session.nextItemId, 1002);

      final first = session.items.first;
      expect(first.status, NavigationItemStatus.reached);
      expect(first.latitude, 16.0033);
      expect(first.isMandatory, isTrue);
      expect(first.reachedAt, DateTime.utc(2026, 10, 20, 2, 15));

      final second = session.items.last;
      expect(second.status, NavigationItemStatus.pending);
      expect(second.latitude, 16.0);
      expect(second.plannedArrival, DateTime.utc(2026, 10, 19, 21));
      expect(session.hasPendingItems, isTrue);
      expect(session.reachedCount, 1);
    });

    test('parses completion reasons', () {
      for (final (raw, reason) in [
        ('RouteFinished', NavigationCompletionReason.routeFinished),
        ('TravelerStopped', NavigationCompletionReason.travelerStopped),
        ('Expired', NavigationCompletionReason.expired),
      ]) {
        final session = NavigationSessionModel.fromJson(
          navigationSessionJson(
            state: 'Completed',
            completionReason: raw,
            exploringItemId: null,
          ),
        );
        expect(session.isCompleted, isTrue);
        expect(session.completionReason, reason);
      }
    });

    test('rejects unknown states, statuses, and missing fields', () {
      expect(
        () => NavigationSessionModel.fromJson(
          navigationSessionJson(state: 'Planning'),
        ),
        throwsFormatException,
      );

      final badStatus = navigationSessionJson();
      ((badStatus['items'] as List).first as Map)['status'] = 'Visited';
      expect(
        () => NavigationSessionModel.fromJson(badStatus),
        throwsFormatException,
      );

      final missingCoordinate = navigationSessionJson();
      ((missingCoordinate['items'] as List).first as Map).remove('latitude');
      expect(
        () => NavigationSessionModel.fromJson(missingCoordinate),
        throwsFormatException,
      );

      expect(
        () => NavigationSessionModel.fromJson(
          navigationSessionJson()..remove('startedAtUtc'),
        ),
        throwsFormatException,
      );
    });
  });
}
