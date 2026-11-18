/// Manual / environment-gated live integration tests for TM-89 / UC-43.
///
/// NOTE: These tests are intentionally SKIPPED in offline CI when the required
/// environment variables below are not configured. Never point these tests at
/// Production SQL Server, Production Redis, or real customer accounts.
///
/// Reproducible isolated setup (before EACH run, because QR tickets are
/// single-use per SRS BR-85 and must be freshly seeded):
/// 1. Start isolated SQL Server 2022 and initialize a fresh database with
///    `Capstone_BE/database/apply-schema.sh`.
/// 2. Start isolated Redis 8.2 with `appendonly yes`, `appendfsync always`,
///    and `/data` mounted (`tm89-aof-always.conf`).
/// 3. Seed synthetic accounts (approved owner Tour Operator, approved rival
///    Tour Operator, active Traveler), a published tour with:
///    - `TM89_SCHEDULE_ID`: today's departure (Asia/Ho_Chi_Minh)
///    - `TM89_OTHER_SCHEDULE_ID`: a second departure today (for WrongSchedule)
///    - `TM89_OUTSIDE_WINDOW_SCHEDULE_ID`: tomorrow's departure (for DepartureNotToday)
///    plus fresh Confirmed/Paid bookings + active cryptographically signed QR
///    tickets for API QR, API manual code, UI QR, UI manual code, a Cancelled
///    booking (QR issued before cancellation), and an Unpaid booking.
/// 4. Start `TripMate.Api` against the isolated SQL + Redis with
///    `CheckInAuditJournal__Enabled=true`.
/// 5. Export the required environment variables listed in `_requiredApiEnvVars`
///    and `_requiredUiEnvVars` and run:
///    `flutter test test/integration/tm89_uc43_live_backend_test.dart --reporter expanded`
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/operator_check_in/data/repositories/operator_check_in_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/usecases/operator_check_in_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_state.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/pages/operator_check_in_page.dart';

const _requiredApiEnvVars = <String>[
  'TM89_API_BASE_URL',
  'TM89_OPERATOR_EMAIL',
  'TM89_OPERATOR_PASSWORD',
  'TM89_OTHER_OPERATOR_EMAIL',
  'TM89_OTHER_OPERATOR_PASSWORD',
  'TM89_TRAVELER_EMAIL',
  'TM89_TRAVELER_PASSWORD',
  'TM89_SCHEDULE_ID',
  'TM89_OTHER_SCHEDULE_ID',
  'TM89_OUTSIDE_WINDOW_SCHEDULE_ID',
  'TM89_API_VALID_QR',
  'TM89_API_MANUAL_BOOKING_CODE',
  'TM89_CANCELLED_QR',
  'TM89_UNPAID_QR',
];

const _requiredUiEnvVars = <String>[
  'TM89_API_BASE_URL',
  'TM89_OPERATOR_EMAIL',
  'TM89_OPERATOR_PASSWORD',
  'TM89_SCHEDULE_ID',
  'TM89_UI_VALID_QR',
  'TM89_UI_MANUAL_BOOKING_CODE',
];

List<String> _missingVars(Map<String, String> env, List<String> required) =>
    required.where((key) => (env[key] ?? '').trim().isEmpty).toList();

String _requireEnv(Map<String, String> env, String key) {
  final value = env[key];
  if (value == null || value.trim().isEmpty) {
    throw StateError('Missing required live integration env var: $key');
  }
  return value;
}

void main() {
  final env = Platform.environment;
  final missingApi = _missingVars(env, _requiredApiEnvVars);
  final missingUi = _missingVars(env, _requiredUiEnvVars);

  if (missingApi.isEmpty || missingUi.isEmpty) {
    LiveTestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
  }

  test(
    'Real Tour Operator auth, repository & cubit execute UC-43 end-to-end against live BE + SQL + Redis',
    () async {
      final baseUrl = Uri.parse(_requireEnv(env, 'TM89_API_BASE_URL'));
      final scheduleId = int.parse(_requireEnv(env, 'TM89_SCHEDULE_ID'));
      final otherScheduleId = int.parse(
        _requireEnv(env, 'TM89_OTHER_SCHEDULE_ID'),
      );
      final outsideWindowScheduleId = int.parse(
        _requireEnv(env, 'TM89_OUTSIDE_WINDOW_SCHEDULE_ID'),
      );
      final validQr = _requireEnv(env, 'TM89_API_VALID_QR');
      final manualCode = _requireEnv(env, 'TM89_API_MANUAL_BOOKING_CODE');
      final cancelledQr = _requireEnv(env, 'TM89_CANCELLED_QR');
      final unpaidQr = _requireEnv(env, 'TM89_UNPAID_QR');

      final ownerToken = await _login(
        baseUrl,
        _requireEnv(env, 'TM89_OPERATOR_EMAIL'),
        _requireEnv(env, 'TM89_OPERATOR_PASSWORD'),
      );
      final otherOperatorToken = await _login(
        baseUrl,
        _requireEnv(env, 'TM89_OTHER_OPERATOR_EMAIL'),
        _requireEnv(env, 'TM89_OTHER_OPERATOR_PASSWORD'),
      );
      final travelerToken = await _login(
        baseUrl,
        _requireEnv(env, 'TM89_TRAVELER_EMAIL'),
        _requireEnv(env, 'TM89_TRAVELER_PASSWORD'),
      );

      final ownerRepo = _repo(baseUrl, ownerToken);
      final otherOperatorRepo = _repo(baseUrl, otherOperatorToken);
      final travelerRepo = _repo(baseUrl, travelerToken);
      final anonymousRepo = _repo(baseUrl, null);

      // 1. Authorization boundaries: unauthenticated 401, Traveler 403, non-owner 403.
      await expectLater(
        anonymousRepo.getTodayDepartures(),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.unauthorized,
          ),
        ),
      );
      await expectLater(
        travelerRepo.getTodayDepartures(),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.forbidden,
          ),
        ),
      );
      await expectLater(
        otherOperatorRepo.scanCheckIn(
          scheduleId: scheduleId,
          qrContent: validQr,
        ),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.scheduleForbidden,
          ),
        ),
      );

      // 2. Owner loads departures and initial progress.
      final departures = await ownerRepo.getTodayDepartures();
      expect(departures.any((d) => d.scheduleId == scheduleId), isTrue);
      final initialProgress = await ownerRepo.getDepartureProgress(scheduleId);
      final initialCheckedIn = initialProgress.checkedInParticipants;

      // 3. Invalid QR signature -> 400 checkin.invalid_qr.
      await expectLater(
        ownerRepo.scanCheckIn(
          scheduleId: scheduleId,
          qrContent: 'TM1.forged.invalid_signature',
        ),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.invalidQr,
          ),
        ),
      );

      // 4. Wrong departure schedule -> 409 checkin.wrong_schedule.
      await expectLater(
        ownerRepo.scanCheckIn(scheduleId: otherScheduleId, qrContent: validQr),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.wrongSchedule,
          ),
        ),
      );

      // 5. Outside departure window -> 409 checkin.departure_not_today.
      await expectLater(
        ownerRepo.scanCheckIn(
          scheduleId: outsideWindowScheduleId,
          qrContent: validQr,
        ),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.departureNotToday,
          ),
        ),
      );

      // 6. Cancelled booking -> 409 checkin.booking_cancelled.
      await expectLater(
        ownerRepo.scanCheckIn(scheduleId: scheduleId, qrContent: cancelledQr),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.bookingCancelled,
          ),
        ),
      );

      // 7. Unpaid booking -> 409 checkin.booking_not_confirmed.
      await expectLater(
        ownerRepo.scanCheckIn(scheduleId: scheduleId, qrContent: unpaidQr),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.bookingNotConfirmed,
          ),
        ),
      );

      // 8. Valid QR check-in -> 200 OK & counter increments by participant quantity.
      final validResult = await ownerRepo.scanCheckIn(
        scheduleId: scheduleId,
        qrContent: validQr,
      );
      expect(validResult.participantCount, greaterThan(0));
      expect(
        validResult.departure.checkedInParticipants,
        initialCheckedIn + validResult.participantCount,
      );

      // 9. Duplicate QR scan -> 409 checkin.already_used with previous checkedInAt.
      await expectLater(
        ownerRepo.scanCheckIn(scheduleId: scheduleId, qrContent: validQr),
        throwsA(
          isA<CheckInFailure>()
              .having((f) => f.kind, 'kind', CheckInFailureKind.alreadyUsed)
              .having((f) => f.checkedInAt, 'checkedInAt', isNotNull)
              .having(
                (f) => f.ticketCode,
                'ticketCode',
                validResult.ticketCode,
              ),
        ),
      );

      // 10. Manual booking-code fallback -> 200 OK & reconciled across progress/departures.
      final manualResult = await ownerRepo.scanCheckIn(
        scheduleId: scheduleId,
        bookingCode: manualCode,
      );
      expect(
        manualResult.departure.checkedInParticipants,
        validResult.departure.checkedInParticipants +
            manualResult.participantCount,
      );

      final refreshedProgress = await ownerRepo.getDepartureProgress(
        scheduleId,
      );
      expect(refreshedProgress, manualResult.departure);
      final refreshedDepartures = await ownerRepo.getTodayDepartures();
      final matching = refreshedDepartures.firstWhere(
        (d) => d.scheduleId == scheduleId,
      );
      expect(
        matching.checkedInParticipants,
        manualResult.departure.checkedInParticipants,
      );
      expect(
        matching.waitingParticipants,
        manualResult.departure.waitingParticipants,
      );
    },
    skip: missingApi.isEmpty
        ? null
        : 'Skipped live BE E2E API test; missing env vars: ${missingApi.join(', ')}',
  );

  group(
    'Live Widget E2E',
    () {
      testWidgets(
        'Real OperatorCheckInPage widget flow executes live QR scan, rapid-scan 1-HTTP-call latch, duplicate, invalid, and manual fallback against live BE',
        (tester) async {
          final baseUrl = Uri.parse(_requireEnv(env, 'TM89_API_BASE_URL'));
          final scheduleId = int.parse(_requireEnv(env, 'TM89_SCHEDULE_ID'));
          final uiQr = _requireEnv(env, 'TM89_UI_VALID_QR');
          final uiManualCode = _requireEnv(env, 'TM89_UI_MANUAL_BOOKING_CODE');

          final ownerToken = await tester.runAsync(
            () => _login(
              baseUrl,
              _requireEnv(env, 'TM89_OPERATOR_EMAIL'),
              _requireEnv(env, 'TM89_OPERATOR_PASSWORD'),
            ),
          );

          var scanPostCount = 0;
          final client = _dioClient(baseUrl, ownerToken);
          client.dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.method == 'POST' &&
                    options.path.endsWith('/api/v1/operator/check-in/scan')) {
                  scanPostCount++;
                }
                handler.next(options);
              },
            ),
          );
          final repo = OperatorCheckInRepositoryImpl(client);
          final cubit = OperatorCheckInCubit(
            getTodayDepartures: GetOperatorTodayDeparturesUseCase(repo),
            getDepartureProgress: GetDepartureProgressUseCase(repo),
            scanCheckIn: ScanCheckInUseCase(repo),
          );
          addTearDown(cubit.close);

          late ValueChanged<String> detect;
          await tester.pumpWidget(
            MaterialApp(
              home: BlocProvider<OperatorCheckInCubit>.value(
                value: cubit,
                child: OperatorCheckInPage(
                  initialScheduleId: scheduleId,
                  scannerBuilder:
                      (context, {required ValueChanged<String> onDetect}) {
                        detect = onDetect;
                        return const SizedBox(key: Key('live-scanner-slot'));
                      },
                ),
              ),
            ),
          );

          await _waitUntil(
            tester,
            () =>
                cubit.state is OperatorCheckInLoaded &&
                (cubit.state as OperatorCheckInLoaded).selectedDeparture !=
                    null,
          );
          final beforeScan = cubit.state as OperatorCheckInLoaded;
          final beforeCheckedIn = beforeScan.progress!.checkedInParticipants;

          // 1. Fire rapid repeated scans of the same valid QR: prove via real Dio interceptor that ONLY 1 POST /scan occurs.
          detect(uiQr);
          detect(uiQr);
          detect(uiQr);

          await _waitUntil(
            tester,
            () =>
                cubit.state is OperatorCheckInLoaded &&
                !(cubit.state as OperatorCheckInLoaded).isSubmittingScan &&
                (cubit.state as OperatorCheckInLoaded).lastResult != null,
          );
          expect(scanPostCount, 1);
          final afterValid = cubit.state as OperatorCheckInLoaded;
          expect(afterValid.lastResult, isNotNull);
          expect(
            afterValid.progress!.checkedInParticipants,
            beforeCheckedIn + afterValid.lastResult!.participantCount,
          );
          expect(
            afterValid.selectedDeparture!.checkedInParticipants,
            afterValid.progress!.checkedInParticipants,
          );
          expect(find.textContaining('accepted'), findsOneWidget);

          // 2. Tap 'Scan next traveler', then re-scan same QR -> real 409 alreadyUsed warning banner.
          await tester.tap(find.text('Scan next traveler'));
          await tester.pump();
          detect(uiQr);
          await _waitUntil(
            tester,
            () =>
                cubit.state is OperatorCheckInLoaded &&
                !(cubit.state as OperatorCheckInLoaded).isSubmittingScan &&
                (cubit.state as OperatorCheckInLoaded).lastFailure != null,
          );
          expect(scanPostCount, 2);
          expect(
            (cubit.state as OperatorCheckInLoaded).lastFailure?.kind,
            CheckInFailureKind.alreadyUsed,
          );
          expect(find.textContaining('already used'), findsOneWidget);
          expect(
            find.textContaining('previously checked in at'),
            findsOneWidget,
          );

          // 3. Tap 'Scan next traveler', then scan invalid QR -> real 400 invalidQr rejected banner.
          await tester.tap(find.text('Scan next traveler'));
          await tester.pump();
          detect('TM1.tampered.bad_signature');
          await _waitUntil(
            tester,
            () =>
                cubit.state is OperatorCheckInLoaded &&
                !(cubit.state as OperatorCheckInLoaded).isSubmittingScan &&
                (cubit.state as OperatorCheckInLoaded).lastFailure?.kind ==
                    CheckInFailureKind.invalidQr,
          );
          expect(scanPostCount, 3);
          expect(find.textContaining('rejected'), findsOneWidget);

          // 4. Manual booking-code fallback through real dialog -> real 200 OK & progress update.
          await tester.tap(find.text('Manual code'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField), uiManualCode);
          await tester.tap(find.text('Check In'));
          await tester.pump();

          await _waitUntil(
            tester,
            () =>
                cubit.state is OperatorCheckInLoaded &&
                !(cubit.state as OperatorCheckInLoaded).isSubmittingScan &&
                (cubit.state as OperatorCheckInLoaded).lastResult != null,
          );
          expect(scanPostCount, 4);
          final afterManual = cubit.state as OperatorCheckInLoaded;
          expect(afterManual.lastResult!.bookingCode, uiManualCode);
          expect(
            afterManual.progress!.checkedInParticipants,
            afterValid.progress!.checkedInParticipants +
                afterManual.lastResult!.participantCount,
          );
          expect(find.textContaining('accepted'), findsOneWidget);
        },
      );
    },
    skip: missingUi.isEmpty
        ? null
        : 'Skipped live BE E2E Widget test; missing env vars: ${missingUi.join(', ')}',
  );
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (predicate()) return;
  }
  fail('Timed out waiting for live backend widget state.');
}

Future<String> _login(Uri baseUrl, String email, String password) async {
  final client = _dioClient(baseUrl, null);
  final response = await client.dio.post<dynamic>(
    '/api/v1/auth/login',
    data: {'email': email, 'password': password},
  );
  final body = Map<String, dynamic>.from(response.data as Map);
  final data = body['data'] is Map
      ? Map<String, dynamic>.from(body['data'] as Map)
      : body;
  final token = (data['accessToken'] ?? data['AccessToken']) as String?;
  if (token == null || token.isEmpty) {
    throw StateError('Login response did not contain accessToken.');
  }
  return token;
}

DioClient _dioClient(Uri baseUrl, String? token) => DioClient(
  config: AppConfig(environment: Environment.development, apiBaseUrl: baseUrl),
  secureStorage: _TokenStorage(token),
);

OperatorCheckInRepositoryImpl _repo(Uri baseUrl, String? token) =>
    OperatorCheckInRepositoryImpl(_dioClient(baseUrl, token));

final class _TokenStorage implements SecureStorageService {
  const _TokenStorage(this.token);
  final String? token;

  @override
  Future<String?> read(String key) async =>
      key == AppConstants.accessTokenKey ? token : null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}
}
