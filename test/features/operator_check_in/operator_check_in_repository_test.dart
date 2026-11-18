import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/operator_check_in/data/models/operator_check_in_json.dart';
import 'package:trip_mate_mobile/features/operator_check_in/data/repositories/demo_operator_check_in_repository.dart';
import 'package:trip_mate_mobile/features/operator_check_in/data/repositories/operator_check_in_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';

final class _NullStorage implements SecureStorageService {
  const _NullStorage();
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
}

void main() {
  group('OperatorCheckInJson Parser', () {
    test('parses departure summary list correctly', () {
      final json = [
        {
          'scheduleId': 101,
          'tourId': 1,
          'tourTitle': 'Hanoi Old Quarter & Street Food Walking Tour',
          'startAtUtc': '2026-10-30T08:00:00Z',
          'endAtUtc': '2026-10-30T17:00:00Z',
          'meetingPoint': 'Hanoi Opera House, 1 Trang Tien, Hoan Kiem, Hanoi',
          'status': 'Open',
          'checkedInParticipants': 18,
          'totalEligibleParticipants': 31,
          'waitingParticipants': 13,
        },
      ];

      final list = OperatorCheckInJson.departureSummaryList(json);
      expect(list.length, 1);
      final item = list.first;
      expect(item.scheduleId, 101);
      expect(item.tourId, 1);
      expect(item.tourTitle, 'Hanoi Old Quarter & Street Food Walking Tour');
      expect(item.checkedInParticipants, 18);
      expect(item.totalEligibleParticipants, 31);
      expect(item.waitingParticipants, 13);
      expect(item.isFullyCheckedIn, isFalse);
    });

    test('parses departure progress correctly', () {
      final json = {
        'scheduleId': 101,
        'tourTitle': 'Hanoi Old Quarter & Street Food Walking Tour',
        'startAtUtc': '2026-10-30T08:00:00Z',
        'endAtUtc': '2026-10-30T17:00:00Z',
        'meetingPoint': 'Hanoi Opera House',
        'checkedInParticipants': 31,
        'totalEligibleParticipants': 31,
        'waitingParticipants': 0,
      };

      final progress = OperatorCheckInJson.departureProgress(json);
      expect(progress.scheduleId, 101);
      expect(progress.checkedInParticipants, 31);
      expect(progress.totalEligibleParticipants, 31);
      expect(progress.waitingParticipants, 0);
      expect(progress.isFullyCheckedIn, isTrue);
    });

    test('parses check-in result correctly', () {
      final json = {
        'ticketCode': 'TK-20261030-0012',
        'bookingCode': 'BK-20261030-0042',
        'passengerName': 'Le Thi Thu Ha',
        'participantCount': 2,
        'checkedInAtUtc': '2026-10-30T08:24:00Z',
        'departure': {
          'scheduleId': 101,
          'tourTitle': 'Hanoi Old Quarter Tour',
          'startAtUtc': '2026-10-30T08:00:00Z',
          'endAtUtc': '2026-10-30T17:00:00Z',
          'meetingPoint': 'Opera House',
          'checkedInParticipants': 19,
          'totalEligibleParticipants': 31,
          'waitingParticipants': 12,
        },
      };

      final result = OperatorCheckInJson.checkInResult(json);
      expect(result.ticketCode, 'TK-20261030-0012');
      expect(result.bookingCode, 'BK-20261030-0042');
      expect(result.passengerName, 'Le Thi Thu Ha');
      expect(result.participantCount, 2);
      expect(result.departure.checkedInParticipants, 19);
    });
  });

  group('DemoOperatorCheckInRepository', () {
    const repo = DemoOperatorCheckInRepository();

    test('getTodayDepartures returns predefined demo departures', () async {
      final departures = await repo.getTodayDepartures();
      expect(departures, isNotEmpty);
      expect(departures.first.scheduleId, 101);
    });

    test('getDepartureProgress returns departure progress', () async {
      final progress = await repo.getDepartureProgress(101);
      expect(progress.scheduleId, 101);
      expect(progress.totalEligibleParticipants, greaterThan(0));
    });

    test('scanCheckIn returns success for valid code', () async {
      final result = await repo.scanCheckIn(
        scheduleId: 101,
        bookingCode: 'BK-20261030-0042',
      );

      expect(result.bookingCode, 'BK-20261030-0042');
      expect(result.participantCount, greaterThan(0));
    });

    test('scanCheckIn throws alreadyUsed for already used code', () async {
      expect(
        () => repo.scanCheckIn(scheduleId: 101, bookingCode: 'USED-001'),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.alreadyUsed,
          ),
        ),
      );
    });

    test('scanCheckIn throws wrongSchedule for wrong schedule code', () async {
      expect(
        () => repo.scanCheckIn(scheduleId: 101, bookingCode: 'WRONG-SCHED'),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.wrongSchedule,
          ),
        ),
      );
    });
  });

  group('OperatorCheckInRepositoryImpl Error Mapping', () {
    OperatorCheckInRepositoryImpl buildRepo(
      int statusCode,
      Map<String, dynamic> body,
    ) {
      final client = DioClient(
        config: AppConfig(
          environment: Environment.development,
          apiBaseUrl: Uri.parse('http://localhost:5000'),
        ),
        secureStorage: const _NullStorage(),
      );
      client.dio.httpClientAdapter = _StubAdapter((_) async {
        return ResponseBody.fromString(
          jsonEncode(body),
          statusCode,
          headers: {
            Headers.contentTypeHeader: ['application/problem+json'],
          },
        );
      });
      return OperatorCheckInRepositoryImpl(client);
    }

    test('maps MSG127 / 503 to system failure with message', () async {
      final repo = buildRepo(503, {
        'errorCode': 'MSG127',
        'title':
            'TripMate is temporarily unable to process your request. Please check your connection and try again.',
      });

      await expectLater(
        repo.scanCheckIn(scheduleId: 101, qrContent: 'QR'),
        throwsA(
          isA<CheckInFailure>()
              .having((f) => f.kind, 'kind', CheckInFailureKind.system)
              .having(
                (f) => f.message,
                'message',
                contains('temporarily unable'),
              ),
        ),
      );
    });

    test('maps checkin.already_used with metadata fields', () async {
      final repo = buildRepo(409, {
        'errorCode': 'checkin.already_used',
        'title': 'Ticket TK-1 was already checked in.',
        'checkedInAt': '2026-10-30T08:15:00Z',
        'ticketCode': 'TK-1',
        'bookingCode': 'BK-1',
        'passengerName': 'Nguyen Van A',
      });

      await expectLater(
        repo.scanCheckIn(scheduleId: 101, qrContent: 'QR'),
        throwsA(
          isA<CheckInFailure>()
              .having((f) => f.kind, 'kind', CheckInFailureKind.alreadyUsed)
              .having((f) => f.ticketCode, 'ticketCode', 'TK-1')
              .having((f) => f.bookingCode, 'bookingCode', 'BK-1')
              .having((f) => f.passengerName, 'passengerName', 'Nguyen Van A')
              .having(
                (f) => f.checkedInAt,
                'checkedInAt',
                DateTime.utc(2026, 10, 30, 8, 15),
              ),
        ),
      );
    });

    test(
      'maps 400 validation problem without errorCode to invalidInput',
      () async {
        final repo = buildRepo(400, {
          'title': 'One or more validation errors occurred.',
        });

        await expectLater(
          repo.scanCheckIn(scheduleId: 101, bookingCode: ' '),
          throwsA(
            isA<CheckInFailure>().having(
              (f) => f.kind,
              'kind',
              CheckInFailureKind.invalidInput,
            ),
          ),
        );
      },
    );

    for (final entry in <(int, String, CheckInFailureKind)>[
      (400, 'checkin.invalid_qr', CheckInFailureKind.invalidQr),
      (403, 'checkin.schedule_forbidden', CheckInFailureKind.scheduleForbidden),
      (409, 'checkin.wrong_schedule', CheckInFailureKind.wrongSchedule),
      (409, 'checkin.booking_cancelled', CheckInFailureKind.bookingCancelled),
      (
        409,
        'checkin.booking_not_confirmed',
        CheckInFailureKind.bookingNotConfirmed,
      ),
      (
        409,
        'checkin.departure_not_today',
        CheckInFailureKind.departureNotToday,
      ),
      (404, 'checkin.ticket_not_found', CheckInFailureKind.ticketNotFound),
      (401, 'unknown', CheckInFailureKind.unauthorized),
      (403, 'operator.tour.access_required', CheckInFailureKind.forbidden),
    ]) {
      test('maps ${entry.$1} ${entry.$2} to ${entry.$3}', () async {
        final repo = buildRepo(entry.$1, {
          'errorCode': entry.$2,
          'title': 'Failure for ${entry.$2}',
        });

        await expectLater(
          repo.scanCheckIn(scheduleId: 101, qrContent: 'QR'),
          throwsA(
            isA<CheckInFailure>().having((f) => f.kind, 'kind', entry.$3),
          ),
        );
      });
    }

    test(
      'maps 400 validation error on read endpoints without injecting QR/manual-code message',
      () async {
        final departuresRepo = buildRepo(400, {
          'title': 'Invalid targetDate format.',
        });
        await expectLater(
          departuresRepo.getTodayDepartures(targetDate: DateTime(2026, 10, 30)),
          throwsA(
            isA<CheckInFailure>()
                .having((f) => f.kind, 'kind', CheckInFailureKind.invalidInput)
                .having(
                  (f) => f.message,
                  'message',
                  'Invalid targetDate format.',
                ),
          ),
        );

        final progressRepo = buildRepo(400, const {});
        await expectLater(
          progressRepo.getDepartureProgress(101),
          throwsA(
            isA<CheckInFailure>()
                .having((f) => f.kind, 'kind', CheckInFailureKind.invalidInput)
                .having((f) => f.message, 'message', isNull),
          ),
        );
      },
    );
  });
}
