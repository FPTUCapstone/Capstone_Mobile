import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/data/datasources/operator_weather_safety_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/data/repositories/operator_weather_safety_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';

import '../support/emergency_fixtures.dart';
import '../support/fake_dio_adapter.dart';

void main() {
  late FakeDioAdapter http;
  late OperatorWeatherSafetyRepositoryImpl repository;

  setUp(() {
    final client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: _EmptySecureStorage(),
    );
    http = FakeDioAdapter();
    client.dio.httpClientAdapter = http;
    repository = OperatorWeatherSafetyRepositoryImpl(
      DioOperatorWeatherSafetyRemoteDataSource(client),
    );
  });

  const cancel = CancelBeforeDepartureDecision(
    tourId: 12,
    scheduleId: 31,
    impactVersion: validImpactVersion,
    reason: EmergencyReason.weatherEmergency,
    reasonDetails: 'Storm warning',
    emergencyContact: '+84 900 000 000',
  );
  final stop = EmergencyStopDecision(
    tourId: 12,
    scheduleId: 31,
    impactVersion: validImpactVersion,
    reason: EmergencyReason.safetyIncident,
    reasonDetails: 'Road closed',
    immediateInstructions: 'Stay at the shelter.',
    emergencyContact: '+84 900 000 000',
  );

  group('reviews', () {
    test('parses a complete review and keeps backend order', () async {
      http.reply(200, [reviewJson(id: 9), reviewJson(id: 7)]);

      final reviews = await repository.getReviews();

      expect(
        http.requests.single.path,
        '/api/v1/operator/weather-safety-reviews',
      );
      expect(reviews.map((review) => review.id), [9, 7]);
      expect(
        reviews.first.status,
        WeatherSafetyReviewStatus.pendingAcknowledgement,
      );
      expect(reviews.first.eventType, 'Storm');
      expect(reviews.first.officialRiskLevel, 3);
      expect(
        reviews.first.acknowledgementDeadlineUtc,
        DateTime.utc(2026, 11, 9, 9),
      );
    });

    test('keeps a review whose weather fields are all null', () async {
      final json = reviewJson()
        ..addAll({
          'eventType': null,
          'severity': null,
          'description': null,
          'validFromUtc': null,
          'validToUtc': null,
          'originalAuthority': null,
          'officialVietnamRiskLevel': null,
          'verifiedDirective': null,
          'affectedAreaSummary': null,
        });
      http.reply(200, json);

      final review = await repository.getReview(7);

      expect(review.eventType, isNull);
      expect(review.officialRiskLevel, isNull);
      expect(review.affectedAreaSummary, isNull);
    });

    test(
      'an unknown status stays unknown and is not treated as closed',
      () async {
        http.reply(200, reviewJson(status: 'SomethingNew'));

        final review = await repository.getReview(7);

        expect(review.status, WeatherSafetyReviewStatus.unknown);
        expect(review.needsAttention, isFalse);
      },
    );

    test('a review without its critical ids fails closed', () async {
      http.reply(200, reviewJson()..remove('tourScheduleId'));

      await expectLater(
        repository.getReview(7),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test(
      'a malformed row fails the whole list rather than hiding an alert',
      () async {
        http.reply(200, [
          reviewJson(),
          {'id': 'x'},
        ]);

        await expectLater(
          repository.getReviews(),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );

    test(
      'acknowledge posts the instructions and returns the new state',
      () async {
        http.reply(200, reviewJson(status: 'Acknowledged'));

        final review = await repository.acknowledgeReview(
          7,
          immediateInstructions: 'Keep guests indoors.',
        );

        final request = http.requests.single;
        expect(request.method, 'POST');
        expect(
          request.path,
          '/api/v1/operator/weather-safety-reviews/7/acknowledge',
        );
        expect(request.data, {'immediateInstructions': 'Keep guests indoors.'});
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
        expect(review.status, WeatherSafetyReviewStatus.acknowledged);
      },
    );

    test('a closed review is reported as a stable failure', () async {
      http.reply(409, problem('weather_safety_review.already_closed'));

      await expectLater(
        repository.acknowledgeReview(7),
        throwsA(
          isA<EmergencyTourFailure>().having(
            (failure) => failure.reason,
            'reason',
            EmergencyTourFailureReason.reviewClosed,
          ),
        ),
      );
    });
  });

  group('impact', () {
    test('parses the preview', () async {
      http.reply(200, impactJson(action: 'EmergencyStopActive'));

      final impact = await repository.getImpact(tourId: 12, scheduleId: 31);

      expect(
        http.requests.single.path,
        '/api/v1/operator/tours/12/schedules/31/emergency-impact',
      );
      expect(impact.action, EmergencyAction.emergencyStop);
      expect(impact.totalPassengerCount, 5);
      expect(impact.impactVersion, validImpactVersion);
    });

    for (final field in [
      'impactVersion',
      'hasUnverifiedSessions',
      'scheduleId',
    ]) {
      test('missing $field fails closed', () async {
        http.reply(200, impactJson()..remove(field));

        await expectLater(
          repository.getImpact(tourId: 12, scheduleId: 31),
          throwsA(isA<UnknownFailure>()),
        );
      });
    }

    test('an impact version of the wrong shape fails closed', () async {
      http.reply(200, impactJson(version: 'abc'));

      await expectLater(
        repository.getImpact(tourId: 12, scheduleId: 31),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test('an unsupported action is preserved as unknown', () async {
      http.reply(200, impactJson(action: 'Teleport'));

      final impact = await repository.getImpact(tourId: 12, scheduleId: 31);

      expect(impact.action, EmergencyAction.unknown);
    });
  });

  group('terminal commands', () {
    test(
      'cancel forwards the idempotency key and the exact contract',
      () async {
        http.reply(200, actionResultJson(action: 'CancelBeforeDeparture'));

        final result = await repository.cancelBeforeDeparture(
          cancel,
          idempotencyKey: 'key-1',
        );

        final request = http.requests.single;
        expect(
          request.path,
          '/api/v1/operator/tours/12/schedules/31/cancel-before-departure',
        );
        expect(request.headers['Idempotency-Key'], 'key-1');
        expect(request.data, {
          'impactVersion': validImpactVersion,
          'reason': 'WeatherEmergency',
          'reasonDetails': 'Storm warning',
          'emergencyContact': '+84 900 000 000',
          'evidenceReference': null,
          'evidenceUrl': null,
          'authorityReference': null,
          'addEvidenceLater': false,
        });
        expect(result.operationId, 90);
        expect(result.action, EmergencyAction.cancelBeforeDeparture);
      },
    );

    test('stop sends the password only in the request body', () async {
      http.reply(200, actionResultJson());

      await repository.emergencyStop(
        stop,
        currentPassword: 'transient-value',
        idempotencyKey: 'key-2',
      );

      final request = http.requests.single;
      expect(
        request.path,
        '/api/v1/operator/tours/12/schedules/31/emergency-stop',
      );
      expect(request.headers['Idempotency-Key'], 'key-2');
      final body = request.data as Map<String, dynamic>;
      expect(body['currentPassword'], 'transient-value');
      expect(body['immediateInstructions'], 'Stay at the shelter.');
      expect(body.containsKey('refundDecisionDueAtUtc'), isFalse);
      expect(request.uri.toString(), isNot(contains('transient-value')));
      expect(request.headers.toString(), isNot(contains('transient-value')));
    });

    test('a decision has no password field to leak', () {
      expect(stop.toString(), isNot(contains('assword')));
      expect(stop.props.join(), isNot(contains('assword')));
    });

    final rejections = {
      'tour_schedule.concurrent_state_changed':
          EmergencyTourFailureReason.staleImpact,
      'tour_schedule.already_terminal': EmergencyTourFailureReason.terminal,
      'tour_schedule.emergency_action_window_invalid':
          EmergencyTourFailureReason.wrongActionWindow,
      'tour_schedule.idempotency_payload_mismatch':
          EmergencyTourFailureReason.idempotencyMismatch,
      'trip_session.link_unverified':
          EmergencyTourFailureReason.unverifiedSessions,
    };
    rejections.forEach((code, reason) {
      test('409 $code maps to $reason', () async {
        http.reply(409, problem(code, title: 'server secret text'));

        await expectLater(
          repository.cancelBeforeDeparture(cancel, idempotencyKey: 'k'),
          throwsA(
            isA<EmergencyTourFailure>()
                .having((failure) => failure.reason, 'reason', reason)
                .having(
                  (failure) => failure.message,
                  'message',
                  isNot(contains('server secret text')),
                ),
          ),
        );
      });
    });

    test(
      '400 user.password_invalid maps to the wrong-password failure',
      () async {
        http.reply(400, problem('user.password_invalid'));

        await expectLater(
          repository.emergencyStop(
            stop,
            currentPassword: 'wrong-value',
            idempotencyKey: 'k',
          ),
          throwsA(
            isA<EmergencyTourFailure>()
                .having(
                  (failure) => failure.reason,
                  'reason',
                  EmergencyTourFailureReason.wrongPassword,
                )
                .having(
                  (failure) => failure.message,
                  'message',
                  isNot(contains('wrong-value')),
                ),
          ),
        );
      },
    );

    test('422 already_completed maps to completed', () async {
      http.reply(422, problem('tour_schedule.already_completed'));

      await expectLater(
        repository.getImpact(tourId: 12, scheduleId: 31),
        throwsA(
          isA<EmergencyTourFailure>().having(
            (failure) => failure.reason,
            'reason',
            EmergencyTourFailureReason.completed,
          ),
        ),
      );
    });

    test('401, 403 and Safe 404 map to the shared failures', () async {
      http
        ..reply(401, problem('auth'))
        ..reply(403, problem('tour_schedule.cancellation_forbidden'))
        ..reply(404, problem('tour_schedule.not_found'));

      await expectLater(
        repository.getImpact(tourId: 1, scheduleId: 1),
        throwsA(isA<AuthenticationFailure>()),
      );
      await expectLater(
        repository.getImpact(tourId: 1, scheduleId: 1),
        throwsA(isA<PermissionFailure>()),
      );
      await expectLater(
        repository.getImpact(tourId: 1, scheduleId: 1),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('$type becomes a network failure', () async {
        http.failWith(type);

        await expectLater(
          repository.cancelBeforeDeparture(cancel, idempotencyKey: 'k'),
          throwsA(isA<NetworkFailure>()),
        );
      });
    }
  });

  group('evidence', () {
    test('adds an https url and reference', () async {
      http.reply(200, {
        'operationId': 90,
        'evidenceProvenance': 'OperatorProvided',
        'evidenceAddedLater': true,
        'updatedAtUtc': '2026-11-10T03:00:00Z',
      });

      final result = await repository.saveEvidence(
        tourId: 12,
        scheduleId: 31,
        evidence: const EmergencyEvidence(
          url: 'https://authority.example/notice',
          authorityReference: 'NCHMF-1',
        ),
      );

      final request = http.requests.single;
      expect(request.method, 'PUT');
      expect(
        request.path,
        '/api/v1/operator/tours/12/schedules/31/emergency-evidence',
      );
      expect(request.data, {
        'evidenceUrl': 'https://authority.example/notice',
        'authorityReference': 'NCHMF-1',
        'evidenceReference': null,
        'withdrawEvidence': false,
        'expectedVersion': null,
      });
      expect(result.operationId, 90);
      expect(result.evidenceAddedLater, isTrue);
    });

    test('withdraw sends no evidence values', () async {
      http.reply(200, {
        'operationId': 90,
        'evidenceProvenance': 'OperatorProvided',
        'evidenceAddedLater': false,
        'updatedAtUtc': '2026-11-10T03:00:00Z',
      });

      await repository.withdrawEvidence(tourId: 12, scheduleId: 31);

      expect(http.requests.single.data, {
        'evidenceUrl': null,
        'authorityReference': null,
        'evidenceReference': null,
        'withdrawEvidence': true,
        'expectedVersion': null,
      });
    });
  });

  group('evidence read', () {
    test('reads the current evidence and its version', () async {
      http.reply(200, {
        'operationId': 90,
        'evidenceUrl': 'https://authority.example/notice',
        'authorityReference': null,
        'evidenceReference': 'REF-1',
        'evidenceProvenance': 'OperatorProvided',
        'evidenceAddedLater': false,
        'evidenceVersion': validImpactVersion,
      });

      final evidence = await repository.getEvidence(tourId: 12, scheduleId: 31);

      expect(http.requests.single.method, 'GET');
      expect(
        http.requests.single.path,
        '/api/v1/operator/tours/12/schedules/31/emergency-evidence',
      );
      expect(evidence.evidence.url, 'https://authority.example/notice');
      expect(evidence.evidence.reference, 'REF-1');
      expect(evidence.version, validImpactVersion);
    });

    test('a save sends the version it read', () async {
      http.reply(200, {
        'operationId': 90,
        'evidenceProvenance': 'OperatorProvided',
        'evidenceAddedLater': false,
        'updatedAtUtc': '2026-11-10T03:00:00Z',
      });

      await repository.saveEvidence(
        tourId: 12,
        scheduleId: 31,
        evidence: const EmergencyEvidence(reference: 'REF-2'),
        expectedVersion: validImpactVersion,
      );

      expect(
        (http.requests.single.data as Map)['expectedVersion'],
        validImpactVersion,
      );
    });

    test('a stale save maps to a stable failure', () async {
      http.reply(409, problem('tour_schedule.emergency_evidence_stale'));

      await expectLater(
        repository.saveEvidence(
          tourId: 12,
          scheduleId: 31,
          evidence: const EmergencyEvidence(reference: 'REF-2'),
          expectedVersion: validImpactVersion,
        ),
        throwsA(
          isA<EmergencyTourFailure>().having(
            (failure) => failure.reason,
            'reason',
            EmergencyTourFailureReason.staleEvidence,
          ),
        ),
      );
    });
  });

  group('evidence url rule', () {
    for (final url in [
      'http://authority.example/notice',
      'ftp://authority.example/notice',
      'https://user:secret@authority.example/notice',
      'authority.example/notice',
      'https://',
      'https://a.example/${'x' * 1000}',
    ]) {
      test('rejects ${url.substring(0, url.length.clamp(0, 40))}', () {
        expect(EmergencyEvidence.isAcceptableUrl(url), isFalse);
      });
    }

    test('accepts an absolute https url', () {
      expect(
        EmergencyEvidence.isAcceptableUrl('https://a.example/n?id=1'),
        isTrue,
      );
    });
  });
}

final class _EmptySecureStorage implements SecureStorageService {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
