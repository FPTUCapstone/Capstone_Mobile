import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/core/platform/device_window.dart';
import 'package:trip_mate_mobile/core/push/dio_push_device_repository.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/core/push/trip_push_messaging.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/data/datasources/operator_weather_safety_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/data/realtime/signalr_operator_weather_safety_realtime.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/data/repositories/operator_weather_safety_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_realtime.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_repository.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_state.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_evidence_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_review_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/pages/emergency_decision_page.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/pages/operator_safety_review_detail_page.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/pages/operator_safety_reviews_page.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/navigation_session_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/data/datasources/traveler_emergency_remote_data_source.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/data/repositories/traveler_emergency_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/usecases/traveler_emergency_use_cases.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_cubit.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/pages/traveler_emergency_page.dart';
import 'package:trip_mate_mobile/shared/widgets/notification_permission_notice.dart';
import 'package:uuid/uuid.dart';

/// Controlled UC-70 E2E against a local Backend and dedicated test database.
/// Every value comes from `--dart-define-from-file` at run time: there are no
/// credentials here, and the test skips when they are absent, so the suite
/// never reaches a real environment by accident.
const _api = String.fromEnvironment('UC70_API');
const _password = String.fromEnvironment('UC70_E2E_PASSWORD');
const _operatorA = String.fromEnvironment('UC70_OPERATOR_A');
const _operatorB = String.fromEnvironment('UC70_OPERATOR_B');
const _travelerA = String.fromEnvironment('UC70_TRAVELER_A');
const _travelerB = String.fromEnvironment('UC70_TRAVELER_B');
const _tourId = int.fromEnvironment('UC70_TOUR_ID');
const _futureSchedule = int.fromEnvironment('UC70_FUTURE_SCHEDULE');
const _futureBooking = int.fromEnvironment('UC70_FUTURE_BOOKING');
const _futureReview = int.fromEnvironment('UC70_FUTURE_REVIEW');
const _activeSchedule = int.fromEnvironment('UC70_ACTIVE_SCHEDULE');
const _activeBooking = int.fromEnvironment('UC70_ACTIVE_BOOKING');
const _activeReview = int.fromEnvironment('UC70_ACTIVE_REVIEW');
const _offlineSchedule = int.fromEnvironment('UC70_OFFLINE_SCHEDULE');
const _offlineReview = int.fromEnvironment('UC70_OFFLINE_REVIEW');
const _activeSession = int.fromEnvironment('UC70_ACTIVE_SESSION');
const _unverifiedTour = int.fromEnvironment('UC70_UNVERIFIED_TOUR');
const _unverifiedSchedule = int.fromEnvironment('UC70_UNVERIFIED_SCHEDULE');

/// The host watches for these lines to change the emulator from outside the app.
void _hostStep(String step) => debugPrint('UC70_HOST_STEP $step');

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skip = _api.isEmpty ? 'Set UC70_* dart-defines to run.' : null;

  late DioClient operatorClient;
  late DioClient foreignOperatorClient;
  late DioClient travelerClient;
  late DioClient foreignTravelerClient;
  late OperatorWeatherSafetyRepositoryImpl operatorRepository;
  late OperatorWeatherSafetyRepositoryImpl foreignOperator;
  late TravelerEmergencyRepositoryImpl travelerRepository;
  late TravelerEmergencyRepositoryImpl foreignTraveler;
  late String operatorToken;
  const online = _Online();

  setUpAll(() async {
    if (skip != null) return;
    final operator = await _signIn(_operatorA);
    operatorToken = operator.token;
    operatorClient = operator.client;
    foreignOperatorClient = (await _signIn(_operatorB)).client;
    travelerClient = (await _signIn(_travelerA)).client;
    foreignTravelerClient = (await _signIn(_travelerB)).client;
    operatorRepository = OperatorWeatherSafetyRepositoryImpl(
      DioOperatorWeatherSafetyRemoteDataSource(operatorClient),
    );
    foreignOperator = OperatorWeatherSafetyRepositoryImpl(
      DioOperatorWeatherSafetyRemoteDataSource(foreignOperatorClient),
    );
    travelerRepository = TravelerEmergencyRepositoryImpl(
      DioTravelerEmergencyRemoteDataSource(travelerClient),
    );
    foreignTraveler = TravelerEmergencyRepositoryImpl(
      DioTravelerEmergencyRemoteDataSource(foreignTravelerClient),
    );
  });

  OperatorSafetyReviewsCubit inbox() => OperatorSafetyReviewsCubit(
    getReviews: GetWeatherSafetyReviewsUseCase(operatorRepository),
    networkInfo: online,
    realtime: const _NoRealtime(),
  );

  EmergencyDecisionCubit decision(int schedule) => EmergencyDecisionCubit(
    tourId: _tourId,
    scheduleId: schedule,
    getImpact: GetEmergencyImpactUseCase(operatorRepository),
    cancelBeforeDeparture: CancelBeforeDepartureUseCase(operatorRepository),
    emergencyStop: EmergencyStopTourUseCase(operatorRepository),
    networkInfo: online,
  );

  Future<void> pumpDecision(WidgetTester tester, int schedule) async {
    final cubit = decision(schedule);
    addTearDown(cubit.close);
    unawaited(cubit.load());
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider(
              create: (_) => EmergencyEvidenceCubit(
                tourId: _tourId,
                scheduleId: schedule,
                save: SaveEmergencyEvidenceUseCase(operatorRepository),
                withdraw: WithdrawEmergencyEvidenceUseCase(operatorRepository),
                read: GetEmergencyEvidenceUseCase(operatorRepository),
                networkInfo: online,
              ),
            ),
          ],
          child: EmergencyDecisionPage(
            tourId: _tourId,
            scheduleId: schedule,
            window: const ChannelDeviceWindow(),
          ),
        ),
      ),
    );
    await _until(tester, find.byKey(const Key('emergency-decision-loaded')));
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await reveal(tester, field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    // The real keyboard moves the layout while it closes.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final target = find.byKey(Key(key));
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('Operator on Android against the local Backend', () {
    testWidgets('S2 inbox lists the reviews with a real badge count', (
      tester,
    ) async {
      final cubit = inbox();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const OperatorSafetyReviewsPage(),
          ),
        ),
      );
      await _until(tester, find.text('UC70 controlled E2E tour'));

      expect(
        cubit.state.reviews.map((review) => review.id),
        containsAll([_activeReview, _futureReview, _offlineReview]),
      );
      expect(cubit.state.badgeCount, greaterThanOrEqualTo(3));
      expect(find.text('UC70 controlled E2E tour'), findsWidgets);
    }, skip: skip != null);

    testWidgets('S3 acknowledge on the detail page changes only the review', (
      tester,
    ) async {
      final cubit = OperatorSafetyReviewDetailCubit(
        reviewId: _futureReview,
        getReview: GetWeatherSafetyReviewUseCase(operatorRepository),
        acknowledge: AcknowledgeWeatherSafetyReviewUseCase(operatorRepository),
        networkInfo: online,
      );
      addTearDown(cubit.close);
      unawaited(cubit.load());
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const OperatorSafetyReviewDetailPage(),
          ),
        ),
      );
      await _until(tester, find.byKey(const Key('safety-acknowledge')));
      expect(find.textContaining('Continue'), findsNothing);

      await tapKey(tester, 'safety-acknowledge');
      await _until(tester, find.text('ACKNOWLEDGED'));

      expect(find.text('ACKNOWLEDGED'), findsOneWidget);
      final fresh = await operatorRepository.getReview(_futureReview);
      expect(fresh.status, WeatherSafetyReviewStatus.acknowledged);
      expect(fresh.scheduleStatus, 'Scheduled');
      final impact = await operatorRepository.getImpact(
        tourId: _tourId,
        scheduleId: _futureSchedule,
      );
      expect(impact.action, EmergencyAction.cancelBeforeDeparture);
    }, skip: skip != null);

    testWidgets('S3b replaying acknowledge is accepted and idempotent', (
      tester,
    ) async {
      final first = await operatorRepository.getReview(_futureReview);
      final again = await operatorRepository.acknowledgeReview(_futureReview);

      expect(again.status, WeatherSafetyReviewStatus.acknowledged);
      expect(again.acknowledgedAtUtc, first.acknowledgedAtUtc);
    }, skip: skip != null);

    testWidgets('S10 a foreign Operator gets Safe 404 everywhere', (
      tester,
    ) async {
      await expectLater(
        foreignOperator.getReview(_futureReview),
        throwsA(isA<NotFoundFailure>()),
      );
      await expectLater(
        foreignOperator.acknowledgeReview(_activeReview),
        throwsA(isA<NotFoundFailure>()),
      );
      await expectLater(
        foreignOperator.getImpact(tourId: _tourId, scheduleId: _futureSchedule),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(await foreignOperator.getReviews(), isEmpty);
    }, skip: skip != null);

    testWidgets('S9 a stale impact version is rejected by the Backend', (
      tester,
    ) async {
      await expectLater(
        operatorRepository.cancelBeforeDeparture(
          CancelBeforeDepartureDecision(
            tourId: _tourId,
            scheduleId: _futureSchedule,
            impactVersion: 'f' * 64,
            reason: EmergencyReason.weatherEmergency,
            reasonDetails: 'E2E stale probe',
          ),
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(
          isA<EmergencyTourFailure>().having(
            (failure) => failure.reason,
            'reason',
            EmergencyTourFailureReason.staleImpact,
          ),
        ),
      );
    }, skip: skip != null);

    testWidgets('S8 unverified sessions block every action on the real page', (
      tester,
    ) async {
      final cubit = EmergencyDecisionCubit(
        tourId: _unverifiedTour,
        scheduleId: _unverifiedSchedule,
        getImpact: GetEmergencyImpactUseCase(operatorRepository),
        cancelBeforeDeparture: CancelBeforeDepartureUseCase(operatorRepository),
        emergencyStop: EmergencyStopTourUseCase(operatorRepository),
        networkInfo: online,
      );
      addTearDown(cubit.close);
      unawaited(cubit.load());
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider(
                create: (_) => EmergencyEvidenceCubit(
                  tourId: _unverifiedTour,
                  scheduleId: _unverifiedSchedule,
                  save: SaveEmergencyEvidenceUseCase(operatorRepository),
                  withdraw: WithdrawEmergencyEvidenceUseCase(
                    operatorRepository,
                  ),
                  read: GetEmergencyEvidenceUseCase(operatorRepository),
                  networkInfo: online,
                ),
              ),
            ],
            child: EmergencyDecisionPage(
              tourId: _unverifiedTour,
              scheduleId: _unverifiedSchedule,
              window: const ChannelDeviceWindow(),
            ),
          ),
        ),
      );
      await _until(tester, find.textContaining('could not be verified'));

      expect(find.textContaining('could not be verified'), findsOneWidget);
      expect(find.byKey(const Key('emergency-review-decision')), findsNothing);
    }, skip: skip != null);

    testWidgets('S22 offline disables actions, stays readable, submits nothing', (
      tester,
    ) async {
      final network = ConnectivityNetworkInfo(Connectivity());
      final detail = OperatorSafetyReviewDetailCubit(
        reviewId: _offlineReview,
        getReview: GetWeatherSafetyReviewUseCase(operatorRepository),
        acknowledge: AcknowledgeWeatherSafetyReviewUseCase(operatorRepository),
        networkInfo: network,
      );
      final decision = EmergencyDecisionCubit(
        tourId: _tourId,
        scheduleId: _offlineSchedule,
        getImpact: GetEmergencyImpactUseCase(operatorRepository),
        cancelBeforeDeparture: CancelBeforeDepartureUseCase(operatorRepository),
        emergencyStop: EmergencyStopTourUseCase(operatorRepository),
        networkInfo: network,
      );
      addTearDown(detail.close);
      addTearDown(decision.close);
      unawaited(detail.load());
      unawaited(decision.load());
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: detail,
            child: const OperatorSafetyReviewDetailPage(),
          ),
        ),
      );
      await _until(tester, find.byKey(const Key('safety-acknowledge')));
      await _waitFor(
        tester,
        () => decision.state.stage == EmergencyDecisionStage.ready,
      );
      expect(decision.state.stage, EmergencyDecisionStage.ready);

      _hostStep('NETWORK_OFF');
      // A failure below must not leave the next scenarios without a network.
      addTearDown(() => _hostStep('NETWORK_ON'));
      await _waitFor(tester, () => detail.state.isOffline);

      expect(detail.state.isOffline, isTrue);
      await _waitFor(
        tester,
        () => decision.state.blockReason == EmergencyBlockReason.offline,
      );
      expect(decision.state.blockReason, EmergencyBlockReason.offline);
      await tester.pumpAndSettle();
      expect(find.text('Hue'), findsNothing);
      expect(find.text('UC70 controlled E2E tour'), findsOneWidget);
      expect(find.textContaining('out of date'), findsOneWidget);
      final acknowledge = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('safety-acknowledge')),
      );
      expect(acknowledge.onPressed, isNull);

      _hostStep('NETWORK_ON');
      await _waitFor(tester, () => !detail.state.isOffline);
      // A socket opened while the emulator is still switching routes dies about
      // 30 s later, which would look like a hub loss to the scenario after this.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 30)),
      );
      expect(detail.state.isOffline, isFalse);
      await _waitFor(
        tester,
        () => decision.state.stage == EmergencyDecisionStage.ready,
      );
      expect(decision.state.stage, EmergencyDecisionStage.ready);

      final review = await tester.runAsync(
        () => operatorRepository.getReview(_offlineReview),
      );
      expect(review!.status, WeatherSafetyReviewStatus.pendingAcknowledgement);
      expect(review.scheduleStatus, 'Scheduled');
    }, skip: skip != null);

    testWidgets(
      'S20 polling covers a lost hub and stops when it should',
      (tester) async {
        final counting = _CountingReviews(operatorRepository);
        final real = SignalROperatorWeatherSafetyRealtime(
          apiBaseUrl: Uri.parse(_api),
          storage: _Storage(operatorToken),
        );
        final switchable = _SwitchableRealtime(real);
        final cubit = OperatorSafetyReviewsCubit(
          getReviews: GetWeatherSafetyReviewsUseCase(counting),
          networkInfo: online,
          realtime: switchable,
        );
        addTearDown(cubit.close);
        await tester.runAsync(cubit.startSession);
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: cubit,
              child: const OperatorSafetyReviewsPage(),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 3)),
        );
        await tester.pump();

        // Connected: no polling at all.
        final connected = counting.calls;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 35)),
        );
        expect(counting.calls, connected);

        // Hub lost while visible: 30-second polling, one request at a time.
        await tester.runAsync(switchable.disconnect);
        final beforePoll = counting.calls;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 65)),
        );
        expect(counting.calls - beforePoll, inInclusiveRange(2, 3));
        expect(counting.maxInFlight, 1);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Hidden: polling stops.
        cubit.setInboxVisible(false);
        final hidden = counting.calls;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 35)),
        );
        expect(counting.calls, hidden);

        // Back, then reconnected: one recovery refresh and no more polling.
        cubit.setInboxVisible(true);
        await tester.runAsync(switchable.reconnect);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 3)),
        );
        final reconnected = counting.calls;
        expect(reconnected, greaterThan(hidden));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 35)),
        );
        expect(counting.calls, reconnected);

        // A real hint over the real hub triggers a real refresh.
        await tester.runAsync(
          () => operatorRepository.acknowledgeReview(_offlineReview),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 4)),
        );
        expect(counting.calls, greaterThan(reconnected));
        await tester.runAsync(real.stop);
      },
      skip: skip != null,
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets('S5 Cancel Before Departure through the real page', (
      tester,
    ) async {
      await pumpDecision(tester, _futureSchedule);
      expect(find.text('Cancel before departure'), findsOneWidget);

      await enter(tester, 'emergency-reason-details', 'E2E storm warning');
      await enter(tester, 'emergency-contact', '+84 900 000 000');
      await tapKey(tester, 'emergency-review-decision');
      await _until(tester, find.byType(AlertDialog));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await _until(tester, find.byKey(const Key('emergency-success')));

      expect(find.byKey(const Key('emergency-success')), findsOneWidget);
      expect(find.byKey(const Key('evidence-editor')), findsOneWidget);
    }, skip: skip != null);

    testWidgets(
      'S5b a second terminal decision is rejected and offers evidence',
      (tester) async {
        await pumpDecision(tester, _futureSchedule);

        expect(
          find.byKey(const Key('emergency-review-decision')),
          findsNothing,
        );
        expect(
          find.textContaining('already has a final decision'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('evidence-editor')), findsOneWidget);
      },
      skip: skip != null,
    );

    testWidgets('S6 a wrong password is rejected on the real page', (
      tester,
    ) async {
      await pumpDecision(tester, _activeSchedule);
      expect(find.text('Emergency stop'), findsOneWidget);
      _hostStep('CHECK_SECURE_ON');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 6)),
      );

      await enter(tester, 'emergency-reason-details', 'E2E road closed');
      await enter(tester, 'emergency-instructions', 'Stay at the shelter.');
      await enter(tester, 'emergency-contact', 'Hotline +84 900 000 000');
      await enter(tester, 'emergency-password', 'not-the-password');
      await tapKey(tester, 'emergency-review-decision');
      await _until(tester, find.byType(AlertDialog));
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await _until(tester, find.textContaining('could not be verified'));

      expect(find.textContaining('could not be verified'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('emergency-password')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty);
      expect(find.text('Stay at the shelter.'), findsOneWidget);

      final impact = await operatorRepository.getImpact(
        tourId: _tourId,
        scheduleId: _activeSchedule,
      );
      expect(impact.action, EmergencyAction.emergencyStop);
    }, skip: skip != null);

    testWidgets('S7 Emergency Stop with the right password', (tester) async {
      await pumpDecision(tester, _activeSchedule);

      await enter(tester, 'emergency-reason-details', 'E2E road closed');
      await enter(tester, 'emergency-instructions', 'Stay at the shelter.');
      await enter(tester, 'emergency-contact', 'Hotline +84 900 000 000');
      await enter(tester, 'emergency-password', _password);
      await tapKey(tester, 'emergency-review-decision');
      await _until(tester, find.byType(AlertDialog));
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await _until(tester, find.byKey(const Key('emergency-success')));

      expect(find.byKey(const Key('emergency-success')), findsOneWidget);
      expect(find.text('Tour stopped'), findsOneWidget);
      expect(find.text(_password), findsNothing);
    }, skip: skip != null);

    testWidgets('S14 the stopped session blocks Active Trip progression', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      _hostStep('CHECK_SECURE_OFF');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 6)),
      );

      final navigation = NavigationSessionRepositoryImpl(
        dioClient: travelerClient,
      );
      final session = await tester.runAsync(
        () => navigation.getById(_activeSession),
      );
      expect(session!.isInterrupted, isTrue);
      expect(session.bookingId, _activeBooking);
      expect(session.isCompleted, isTrue);

      final failure = await tester.runAsync(() async {
        try {
          await navigation.reachItem(
            sessionId: _activeSession,
            itemId: session.items.first.itemId,
            occurredAt: DateTime.now().toUtc(),
          );
          return null;
        } on Failure catch (failure) {
          return failure;
        }
      });
      expect(
        failure,
        isA<NavigationFailure>().having(
          (value) => value.reason,
          'reason',
          NavigationFailureReason.sessionInterrupted,
        ),
      );
    }, skip: skip != null);

    testWidgets('S11 evidence add, update and withdraw', (tester) async {
      await pumpDecision(tester, _activeSchedule);

      await enter(tester, 'evidence-url', 'https://authority.example/notice');
      await enter(tester, 'evidence-authority', 'E2E-AUTH-1');
      await tapKey(tester, 'evidence-save');
      await _until(tester, find.text('Evidence saved.'));
      expect(find.text('Evidence saved.'), findsOneWidget);

      await enter(tester, 'evidence-reference', 'E2E-REF-2');
      await tapKey(tester, 'evidence-save');
      await _until(tester, find.text('Evidence saved.'));
      expect(find.text('Evidence saved.'), findsOneWidget);

      await tapKey(tester, 'evidence-withdraw');
      await tester.tap(find.byKey(const Key('evidence-withdraw-confirm')));
      await _until(tester, find.text('Evidence withdrawn.'));
      expect(find.text('Evidence withdrawn.'), findsOneWidget);
    }, skip: skip != null);

    testWidgets('S19 SignalR connects with the JWT and hints trigger REST', (
      tester,
    ) async {
      final realtime = SignalROperatorWeatherSafetyRealtime(
        apiBaseUrl: Uri.parse(_api),
        storage: _Storage(operatorToken),
      );
      final connected = realtime.connection.first;
      await realtime.start();

      expect(await connected.timeout(const Duration(seconds: 20)), isTrue);

      final hint = realtime.hints.first;
      await operatorRepository.acknowledgeReview(_activeReview);
      final received = await hint.timeout(const Duration(seconds: 20));
      expect(received.reviewId, _activeReview);
      expect(received.changeType, 'Updated');

      await realtime.stop();
    }, skip: skip != null);
  });

  group('Traveler on Android against the local Backend', () {
    Future<void> pumpNotice(WidgetTester tester, int booking) async {
      final cubit = TravelerEmergencyCubit(
        bookingId: booking,
        getStatus: GetTravelerEmergencyStatusUseCase(travelerRepository),
        acknowledge: AcknowledgeTravelerEmergencyStatusUseCase(
          travelerRepository,
        ),
        networkInfo: online,
      );
      addTearDown(cubit.close);
      unawaited(cubit.load());
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const TravelerEmergencyPage(),
          ),
        ),
      );
      await _until(tester, find.byKey(const Key('emergency-notice-loaded')));
    }

    testWidgets('S12 cancellation notice loads and is acknowledged', (
      tester,
    ) async {
      await pumpNotice(tester, _futureBooking);

      expect(find.text('Tour cancelled'), findsOneWidget);
      expect(find.text('E2E storm warning'), findsOneWidget);

      await tapKey(tester, 'emergency-ack');
      await _until(tester, find.textContaining('Receipt recorded'));
      expect(find.textContaining('Receipt recorded'), findsOneWidget);

      final fresh = await travelerRepository.getStatus(_futureBooking);
      expect(fresh.acknowledgedAtUtc, isNotNull);
      expect(fresh.scheduleStatus, 'Cancelled');
    }, skip: skip != null);

    testWidgets('S13 stop notice leads with instructions and contact', (
      tester,
    ) async {
      await pumpNotice(tester, _activeBooking);

      expect(find.text('Tour stopped for safety'), findsOneWidget);
      expect(find.text('Stay at the shelter.'), findsOneWidget);
      expect(find.textContaining('Hotline'), findsOneWidget);
      expect(find.byKey(const Key('emergency-call')), findsOneWidget);
      expect(find.textContaining('has been completed'), findsNothing);

      await tapKey(tester, 'emergency-ack');
      await _until(tester, find.textContaining('Receipt recorded'));
      expect(find.textContaining('Receipt recorded'), findsOneWidget);
      final fresh = await travelerRepository.getStatus(_activeBooking);
      expect(fresh.isStopped, isTrue);
    }, skip: skip != null);

    testWidgets('S13b acknowledge replay keeps the first receipt time', (
      tester,
    ) async {
      final first = await travelerRepository.getStatus(_activeBooking);
      final again = await travelerRepository.acknowledge(_activeBooking);

      expect(again, first.acknowledgedAtUtc);
    }, skip: skip != null);

    testWidgets('S19 notices are recovered with no push at all', (
      tester,
    ) async {
      final notices = await tester.runAsync(travelerRepository.getNotices);
      expect(
        notices!.map((notice) => notice.bookingId),
        containsAll([_futureBooking, _activeBooking]),
      );
      final stopped = notices.singleWhere(
        (notice) => notice.bookingId == _activeBooking,
      );
      expect(stopped.action, EmergencyAction.emergencyStop);
      expect(stopped.requiresAcknowledgement, isFalse);
    }, skip: skip != null);

    // A fresh install on Android 13+ has no notification permission, so this is
    // the real denied state. Only the prompt is skipped: it was asked before.
    testWidgets('S19c denied permission keeps REST and offers real Settings', (
      tester,
    ) async {
      await tester.runAsync(Firebase.initializeApp);
      final coordinator = PushDeviceCoordinator(
        repository: DioPushDeviceRepository(operatorClient),
        storage: _Storage(operatorToken, permissionAsked: true),
        messaging: FirebaseTripPushMessaging(FirebaseMessaging.instance),
      );
      addTearDown(coordinator.close);

      await tester.runAsync(coordinator.onAuthenticated);
      expect(coordinator.permissionDenied.value, isTrue);
      final notices = await tester.runAsync(travelerRepository.getNotices);
      expect(notices, isNotEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationPermissionNotice(
              denied: coordinator.permissionDenied,
              window: const ChannelDeviceWindow(),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const Key('notification-permission-settings')),
      );
      // The app is behind Settings here: no frames until the host goes back.
      _hostStep('SETTINGS_CHECK_GRANT_BACK');
      // The host answers on its own schedule, so wait for the grant itself.
      for (var i = 0; i < 40 && coordinator.permissionDenied.value; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await tester.runAsync(coordinator.onResumed);
      }
      await tester.pump();
      expect(coordinator.permissionDenied.value, isFalse);
      expect(
        find.byKey(const Key('notification-permission-notice')),
        findsNothing,
      );
    }, skip: skip != null);

    testWidgets('S15 a foreign Traveler gets Safe 404', (tester) async {
      await expectLater(
        foreignTraveler.getStatus(_activeBooking),
        throwsA(isA<NotFoundFailure>()),
      );
      await expectLater(
        foreignTraveler.acknowledge(_futureBooking),
        throwsA(isA<NotFoundFailure>()),
      );
    }, skip: skip != null);
  });
}

/// Real HTTP schedules no frames, so pumpAndSettle cannot wait for it.
Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
}

Future<({DioClient client, String token})> _signIn(String email) async {
  final response = await Dio(BaseOptions(baseUrl: _api))
      .post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email, 'password': _password},
      );
  final data = response.data!['data'] as Map<String, dynamic>;
  final token = data['accessToken'] as String;
  return (
    token: token,
    client: DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse(_api),
      ),
      secureStorage: _Storage(token),
    ),
  );
}

final class _Storage implements SecureStorageService {
  _Storage(this._token, {this.permissionAsked = false});

  final String _token;
  final bool permissionAsked;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => switch (key) {
    AppConstants.accessTokenKey => _token,
    AppConstants.pushPermissionAskedKey when permissionAsked => 'true',
    _ => null,
  };

  @override
  Future<void> write(String key, String value) async {}
}

final class _Online implements NetworkInfo {
  const _Online();

  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

final class _NoRealtime implements OperatorWeatherSafetyRealtime {
  const _NoRealtime();

  @override
  Stream<bool> get connection => const Stream.empty();

  @override
  Stream<WeatherSafetyReviewHint> get hints => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

/// Counts real requests and how many ran at once.
final class _CountingReviews implements OperatorWeatherSafetyRepository {
  _CountingReviews(this._inner);

  final OperatorWeatherSafetyRepository _inner;
  int calls = 0;
  int maxInFlight = 0;
  int _inFlight = 0;

  @override
  Future<List<WeatherSafetyReview>> getReviews() async {
    calls++;
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      return await _inner.getReviews();
    } finally {
      _inFlight--;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The real hub connection, which the test can drop and restore on demand.
final class _SwitchableRealtime implements OperatorWeatherSafetyRealtime {
  _SwitchableRealtime(this._real) {
    _real.connection.listen(_connection.add);
  }

  final SignalROperatorWeatherSafetyRealtime _real;
  final _connection = StreamController<bool>.broadcast();

  Future<void> disconnect() async {
    await _real.stop();
    _connection.add(false);
  }

  Future<void> reconnect() => _real.start();

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  Stream<WeatherSafetyReviewHint> get hints => _real.hints;

  @override
  Future<void> start() => _real.start();

  @override
  Future<void> stop() => _real.stop();
}
