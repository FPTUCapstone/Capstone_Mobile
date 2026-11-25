import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/navigation_session_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';

import '../models/navigation_session_model_test.dart'
    show navigationSessionJson;

const _msg44 = 'No re-routing suggestion is available at the moment.';
const _msg127 =
    'TripMate is temporarily unable to process your request. '
    'Please check your connection and try again.';
const _base = '/api/v1/navigation-sessions/501/rerouting-proposals/77';

void main() {
  late NavigationSessionRepositoryImpl repository;
  late _Adapter adapter;

  setUp(() {
    final client = DioClient(
      config: AppConfig(
        environment: Environment.production,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: const _Storage(),
    );
    adapter = _Adapter();
    client.dio.httpClientAdapter = adapter;
    repository = NavigationSessionRepositoryImpl(dioClient: client);
  });

  group('getProposal', () {
    test('reads the detail contract into a RerouteProposal', () async {
      adapter.body = proposalJson();

      final proposal = await repository.getProposal(
        sessionId: 501,
        proposalId: 77,
      );

      expect(adapter.request?.method, 'GET');
      expect(adapter.request?.path, _base);
      expect(proposal.proposalId, 77);
      expect(proposal.incidentId, 42);
      expect(proposal.status, RerouteStatus.pending);
      expect(proposal.reason.code, 'trip_alert.severe_weather');
      expect(proposal.reason.strategy, 'ReplaceWithIndoor');
      expect(proposal.reason.affectedPoiName, 'Han Market');
      expect(proposal.currentStops.single.name, 'Han Market');
      expect(proposal.currentStops.single.change, isNull);
      expect(proposal.proposedStops.map((stop) => stop.name), [
        'Marble Mountains',
        'Helio Center',
      ]);
      expect(proposal.proposedStops.map((stop) => stop.change), [
        RerouteStopChange.kept,
        RerouteStopChange.added,
      ]);
      expect(proposal.proposedStops.first.isMandatory, isTrue);
      expect(proposal.removedStops, ['Han Market']);
      expect(proposal.affectedStops, ['Han Market']);
      expect(proposal.travelTimeDiffMinutes, -15);
      expect(proposal.arrivalTimeDiffMinutes, -30);
      expect(proposal.proposedAt, DateTime.utc(2026, 11, 25, 3));
      expect(proposal.expiresAt, DateTime.utc(2026, 11, 25, 3, 15));
      expect(proposal.decidedAt, isNull);
    });

    test('maps every status literal, Rejected becoming declined', () async {
      const expected = {
        'Proposed': RerouteStatus.pending,
        'Accepted': RerouteStatus.accepted,
        'Rejected': RerouteStatus.declined,
        'Expired': RerouteStatus.expired,
      };
      for (final entry in expected.entries) {
        adapter.body = proposalJson(status: entry.key);
        final proposal = await repository.getProposal(
          sessionId: 501,
          proposalId: 77,
        );
        expect(proposal.status, entry.value, reason: entry.key);
      }
    });

    test('maps the Moved change and tolerates a missing POI name', () async {
      adapter.body = proposalJson(change: 'Moved', affectedPoiName: null);

      final proposal = await repository.getProposal(
        sessionId: 501,
        proposalId: 77,
      );

      expect(proposal.proposedStops.last.change, RerouteStopChange.moved);
      expect(proposal.reason.affectedPoiName, isNull);
    });

    test('a malformed body is a failure, not a crash', () async {
      adapter.body = {'proposalId': 77};

      await expectLater(
        repository.getProposal(sessionId: 501, proposalId: 77),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('acceptProposal', () {
    test(
      'PUTs acceptance and returns the session on the new version',
      () async {
        adapter.body = navigationSessionJson();

        final session = await repository.acceptProposal(
          sessionId: 501,
          proposalId: 77,
        );

        expect(adapter.request?.method, 'PUT');
        expect(adapter.request?.path, '$_base/acceptance');
        expect(session.sessionId, 501);
        expect(session.itineraryVersion, 3);
      },
    );
  });

  group('rejectProposal', () {
    test('PUTs rejection and accepts the empty 204 answer', () async {
      adapter
        ..body = null
        ..statusCode = 204;

      await repository.rejectProposal(sessionId: 501, proposalId: 77);

      expect(adapter.request?.method, 'PUT');
      expect(adapter.request?.path, '$_base/rejection');
    });
  });

  group('error mapping', () {
    const cases = {
      404: ('rerouting.not_found', ReroutingFailureReason.notFound),
      409: ('rerouting.proposal_expired', ReroutingFailureReason.expired),
    };
    for (final entry in cases.entries) {
      test('${entry.value.$1} becomes MSG44', () async {
        adapter
          ..statusCode = entry.key
          ..body = {'errorCode': entry.value.$1};

        await expectLater(
          repository.acceptProposal(sessionId: 501, proposalId: 77),
          throwsA(
            isA<ReroutingFailure>()
                .having((f) => f.message, 'message', _msg44)
                .having((f) => f.reason, 'reason', entry.value.$2),
          ),
        );
      });
    }

    test('closed and infeasible 409s are told apart', () async {
      for (final (code, reason) in [
        ('rerouting.proposal_closed', ReroutingFailureReason.closed),
        ('rerouting.proposal_infeasible', ReroutingFailureReason.infeasible),
      ]) {
        adapter
          ..statusCode = 409
          ..body = {'errorCode': code};
        await expectLater(
          repository.rejectProposal(sessionId: 501, proposalId: 77),
          throwsA(
            isA<ReroutingFailure>().having((f) => f.reason, 'reason', reason),
          ),
        );
      }
    });

    test('a 500 shows MSG127 and stays a ServerFailure', () async {
      adapter
        ..statusCode = 500
        ..body = {'title': 'boom'};

      await expectLater(
        repository.acceptProposal(sessionId: 501, proposalId: 77),
        throwsA(
          isA<ServerFailure>().having((f) => f.message, 'message', _msg127),
        ),
      );
    });
  });
}

Map<String, dynamic> proposalJson({
  String status = 'Proposed',
  String change = 'Added',
  String? affectedPoiName = 'Han Market',
}) => {
  'proposalId': 77,
  'incidentId': 42,
  'status': status,
  'reason': {
    'code': 'trip_alert.severe_weather',
    'strategy': 'ReplaceWithIndoor',
    'affectedItemId': 1002,
    'affectedPoiName': affectedPoiName,
  },
  'currentStops': [
    {
      'itineraryItemId': 1002,
      'poiId': 13,
      'name': 'Han Market',
      'latitude': 16.07,
      'longitude': 108.22,
      'plannedArrivalUtc': '2026-11-25T04:00:00Z',
      'plannedDepartureUtc': '2026-11-25T05:00:00Z',
      'isMandatory': false,
    },
  ],
  'proposedStops': [
    {
      'poiId': 12,
      'name': 'Marble Mountains',
      'latitude': 16.0,
      'longitude': 108.26,
      'plannedArrivalUtc': '2026-11-25T03:30:00Z',
      'plannedDepartureUtc': '2026-11-25T04:00:00Z',
      'isMandatory': true,
      'transportModeToNext': null,
      'change': 'Kept',
    },
    {
      'poiId': 99,
      'name': 'Helio Center',
      'latitude': 16.03,
      'longitude': 108.21,
      'plannedArrivalUtc': '2026-11-25T04:15:00Z',
      'plannedDepartureUtc': '2026-11-25T05:15:00Z',
      'isMandatory': false,
      'transportModeToNext': 'Car',
      'change': change,
    },
  ],
  'affectedStops': [
    {'itineraryItemId': 1002, 'poiId': 13, 'name': 'Han Market'},
  ],
  'removedStops': [
    {'poiId': 13, 'name': 'Han Market'},
  ],
  'travelTimeDiffMinutes': -15,
  'arrivalTimeDiffMinutes': -30,
  'proposedAtUtc': '2026-11-25T03:00:00Z',
  'expiresAtUtc': '2026-11-25T03:15:00Z',
  'decidedAtUtc': null,
};

final class _Adapter implements HttpClientAdapter {
  Object? body;
  int statusCode = 200;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _Storage implements SecureStorageService {
  const _Storage();
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}
