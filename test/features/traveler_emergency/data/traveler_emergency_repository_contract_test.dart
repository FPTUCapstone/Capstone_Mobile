import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/data/datasources/traveler_emergency_remote_data_source.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/data/repositories/traveler_emergency_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';

import '../../operator_weather_safety/support/emergency_fixtures.dart';
import '../../operator_weather_safety/support/fake_dio_adapter.dart';
import '../support/traveler_emergency_fixtures.dart';

void main() {
  late FakeDioAdapter http;
  late TravelerEmergencyRepositoryImpl repository;

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
    repository = TravelerEmergencyRepositoryImpl(
      DioTravelerEmergencyRemoteDataSource(client),
    );
  });

  test('parses an emergency-stopped status', () async {
    http.reply(200, stoppedStatusJson());

    final status = await repository.getStatus(42);

    expect(
      http.requests.single.path,
      '/api/v1/traveler/tour-bookings/42/emergency-status',
    );
    expect(status.action, EmergencyAction.emergencyStop);
    expect(status.immediateInstructions, 'Stay at the shelter.');
    expect(status.emergencyContact, 'Hotline +84 900 000 000');
    expect(status.acknowledgedAtUtc, isNull);
  });

  group('refund handling and rebooking tour', () {
    test('parses the refund handling and the tour of the departure', () async {
      http.reply(200, stoppedStatusJson());

      final status = await repository.getStatus(42);

      expect(status.refundHandling, RefundHandling.underReview);
      expect(status.tourId, 12);
    });

    final wireValues = {
      'RefundSubmitted': RefundHandling.refundSubmitted,
      'UnderReview': RefundHandling.underReview,
      'NotApplicable': RefundHandling.notApplicable,
      'SomethingNew': RefundHandling.unknown,
      42: RefundHandling.unknown,
    };
    for (final MapEntry(key: wire, value: expected) in wireValues.entries) {
      test('refund handling $wire is $expected', () async {
        http.reply(200, stoppedStatusJson()..['refundHandling'] = wire);

        final status = await repository.getStatus(42);

        expect(status.refundHandling, expected);
      });
    }

    test('an older Backend without the new fields still parses', () async {
      http.reply(
        200,
        stoppedStatusJson()
          ..remove('refundHandling')
          ..remove('tourId'),
      );

      final status = await repository.getStatus(42);

      expect(status.refundHandling, RefundHandling.unknown);
      expect(status.tourId, isNull);
      expect(status.action, EmergencyAction.emergencyStop);
    });

    for (final invalid in [0, -1, '12', null]) {
      test('tour id $invalid is treated as missing', () async {
        http.reply(200, stoppedStatusJson()..['tourId'] = invalid);

        final status = await repository.getStatus(42);

        expect(status.tourId, isNull);
      });
    }

    test('acknowledging keeps refund handling and tour id', () {
      final status = TravelerEmergencyFixture.build(
        refundHandling: RefundHandling.refundSubmitted,
        tourId: 12,
      ).acknowledged(DateTime.utc(2026, 11, 10, 4));

      expect(status.refundHandling, RefundHandling.refundSubmitted);
      expect(status.tourId, 12);
    });
  });

  test('an unknown action value stays unknown', () async {
    http.reply(200, stoppedStatusJson()..['action'] = 'Teleport');

    final status = await repository.getStatus(42);

    expect(status.action, EmergencyAction.unknown);
  });

  for (final field in ['bookingId', 'committedAtUtc', 'scheduleStatus']) {
    test('missing $field fails closed', () async {
      http.reply(200, stoppedStatusJson()..remove(field));

      await expectLater(
        repository.getStatus(42),
        throwsA(isA<UnknownFailure>()),
      );
    });
  }

  test('a foreign or undecided booking is a Safe 404', () async {
    http
      ..reply(404, problem('tour_booking.booking_not_found'))
      ..reply(404, problem('tour_booking.emergency_status_not_found'));

    await expectLater(
      repository.getStatus(42),
      throwsA(isA<NotFoundFailure>()),
    );
    await expectLater(
      repository.getStatus(42),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('acknowledge posts once and returns the receipt time', () async {
    http.reply(200, {
      'bookingId': 42,
      'acknowledgedAtUtc': '2026-11-10T04:00:00Z',
    });

    final acknowledgedAt = await repository.acknowledge(42);

    final request = http.requests.single;
    expect(request.method, 'POST');
    expect(
      request.path,
      '/api/v1/traveler/tour-bookings/42/emergency-status/acknowledge',
    );
    expect(acknowledgedAt, DateTime.utc(2026, 11, 10, 4));
  });

  test('lists notices from the discovery endpoint', () async {
    http.reply(200, [
      {
        'bookingId': 42,
        'scheduleId': 31,
        'action': 'EmergencyStopActive',
        'committedAtUtc': '2026-11-03T02:00:00Z',
        'acknowledgedAtUtc': null,
        'requiresAcknowledgement': true,
      },
    ]);

    final notices = await repository.getNotices();

    expect(
      http.requests.single.path,
      '/api/v1/traveler/tour-bookings/emergency-notices',
    );
    expect(notices.single.bookingId, 42);
    expect(notices.single.action, EmergencyAction.emergencyStop);
    expect(notices.single.requiresAcknowledgement, isTrue);
  });

  test('a notice without its booking id fails closed', () async {
    http.reply(200, [
      {'action': 'EmergencyStopActive'},
    ]);

    await expectLater(repository.getNotices(), throwsA(isA<UnknownFailure>()));
  });

  test('a timeout becomes a network failure', () async {
    http.failWith(DioExceptionType.receiveTimeout);

    await expectLater(
      repository.acknowledge(42),
      throwsA(isA<NetworkFailure>()),
    );
  });

  group('callable contact', () {
    String? dial(String? contact) => TravelerEmergencyFixture.build(
      emergencyContact: contact,
    ).dialableContact;

    test('extracts a phone number from free text', () {
      expect(dial('Hotline +84 900 000 000'), '+84900000000');
      expect(dial('0900-000-000'), '0900000000');
    });

    test('text without a number is not callable', () {
      expect(dial('Ask your tour guide'), isNull);
      expect(dial('Room 12'), isNull);
      expect(dial(null), isNull);
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
