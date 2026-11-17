import 'dart:io';

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

void main() {
  final env = Platform.environment;
  final live =
      env['TM89_API_BASE_URL'] != null &&
      env['TM89_OPERATOR_EMAIL'] != null &&
      env['TM89_OPERATOR_PASSWORD'] != null &&
      env['TM89_SCHEDULE_ID'] != null;

  if (live) {
    LiveTestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
  }

  test(
    'Real Tour Operator auth, repository & cubit execute UC-43 end-to-end against live BE + SQL + Redis',
    () async {
      final baseUrl = Uri.parse(env['TM89_API_BASE_URL']!);
      final scheduleId = int.parse(env['TM89_SCHEDULE_ID']!);
      final otherScheduleId = int.parse(env['TM89_OTHER_SCHEDULE_ID']!);
      final outsideWindowScheduleId = int.parse(
        env['TM89_OUTSIDE_WINDOW_SCHEDULE_ID']!,
      );

      final ownerToken = await _login(
        baseUrl,
        env['TM89_OPERATOR_EMAIL']!,
        env['TM89_OPERATOR_PASSWORD']!,
      );
      final otherOperatorToken = await _login(
        baseUrl,
        env['TM89_OTHER_OPERATOR_EMAIL']!,
        env['TM89_OTHER_OPERATOR_PASSWORD']!,
      );
      final travelerToken = await _login(
        baseUrl,
        env['TM89_TRAVELER_EMAIL']!,
        env['TM89_TRAVELER_PASSWORD']!,
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
          qrContent: env['TM89_API_VALID_QR']!,
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
        ownerRepo.scanCheckIn(
          scheduleId: otherScheduleId,
          qrContent: env['TM89_API_VALID_QR']!,
        ),
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
          qrContent: env['TM89_API_VALID_QR']!,
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
        ownerRepo.scanCheckIn(
          scheduleId: scheduleId,
          qrContent: env['TM89_CANCELLED_QR']!,
        ),
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
        ownerRepo.scanCheckIn(
          scheduleId: scheduleId,
          qrContent: env['TM89_UNPAID_QR']!,
        ),
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
        qrContent: env['TM89_API_VALID_QR']!,
      );
      expect(validResult.participantCount, greaterThan(0));
      expect(
        validResult.departure.checkedInParticipants,
        initialCheckedIn + validResult.participantCount,
      );

      // 9. Duplicate QR scan -> 409 checkin.already_used with previous checkedInAt.
      await expectLater(
        ownerRepo.scanCheckIn(
          scheduleId: scheduleId,
          qrContent: env['TM89_API_VALID_QR']!,
        ),
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
        bookingCode: env['TM89_API_MANUAL_BOOKING_CODE']!,
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
    skip: live ? null : 'Requires TM89 live BE + SQL + Redis test environment.',
  );

  testWidgets(
    'Real OperatorCheckInPage widget flow executes live QR scan, rapid-scan latch, duplicate, invalid, and manual fallback against live BE',
    (tester) async {
      final baseUrl = Uri.parse(env['TM89_API_BASE_URL']!);
      final scheduleId = int.parse(env['TM89_SCHEDULE_ID']!);
      final ownerToken = await tester.runAsync(
        () => _login(
          baseUrl,
          env['TM89_OPERATOR_EMAIL']!,
          env['TM89_OPERATOR_PASSWORD']!,
        ),
      );
      final repo = _repo(baseUrl, ownerToken);
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
            (cubit.state as OperatorCheckInLoaded).selectedDeparture != null,
      );
      final beforeScan = cubit.state as OperatorCheckInLoaded;
      final beforeCheckedIn = beforeScan.progress!.checkedInParticipants;

      // 1. Fire rapid repeated scans of the same valid QR: only ONE submission must occur.
      final uiQr = env['TM89_UI_VALID_QR']!;
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
      expect(
        (cubit.state as OperatorCheckInLoaded).lastFailure?.kind,
        CheckInFailureKind.alreadyUsed,
      );
      expect(find.textContaining('already used'), findsOneWidget);
      expect(find.textContaining('previously checked in at'), findsOneWidget);

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
      expect(find.textContaining('rejected'), findsOneWidget);

      // 4. Manual booking-code fallback through real dialog -> real 200 OK & progress update.
      await tester.tap(find.text('Manual code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        env['TM89_UI_MANUAL_BOOKING_CODE']!,
      );
      await tester.tap(find.text('Check In'));
      await tester.pump();

      await _waitUntil(
        tester,
        () =>
            cubit.state is OperatorCheckInLoaded &&
            !(cubit.state as OperatorCheckInLoaded).isSubmittingScan &&
            (cubit.state as OperatorCheckInLoaded).lastResult != null,
      );
      final afterManual = cubit.state as OperatorCheckInLoaded;
      expect(
        afterManual.lastResult!.bookingCode,
        env['TM89_UI_MANUAL_BOOKING_CODE']!,
      );
      expect(
        afterManual.progress!.checkedInParticipants,
        afterValid.progress!.checkedInParticipants +
            afterManual.lastResult!.participantCount,
      );
      expect(find.textContaining('accepted'), findsOneWidget);
    },
    skip: !live,
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
  final client = DioClient(
    config: AppConfig(
      environment: Environment.development,
      apiBaseUrl: baseUrl,
    ),
    secureStorage: const _TokenStorage(null),
  );
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
    throw StateError('Login response did not contain accessToken: $body');
  }
  return token;
}

OperatorCheckInRepositoryImpl _repo(Uri baseUrl, String? token) =>
    OperatorCheckInRepositoryImpl(
      DioClient(
        config: AppConfig(
          environment: Environment.development,
          apiBaseUrl: baseUrl,
        ),
        secureStorage: _TokenStorage(token),
      ),
    );

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
