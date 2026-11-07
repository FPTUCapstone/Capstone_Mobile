import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_realtime.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_review_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_review_detail_state.dart';

import '../support/fake_operator_weather_safety_repository.dart';

void main() {
  late FakeOperatorWeatherSafetyRepository repository;
  late FakeNetworkInfo network;

  setUp(() {
    repository = FakeOperatorWeatherSafetyRepository()
      ..reviewResult = review()
      ..acknowledgeResult = review(
        status: WeatherSafetyReviewStatus.acknowledged,
        immediateInstructions: 'Keep guests indoors.',
      );
    network = FakeNetworkInfo();
  });

  OperatorSafetyReviewDetailCubit create() => OperatorSafetyReviewDetailCubit(
    reviewId: 7,
    getReview: GetWeatherSafetyReviewUseCase(repository),
    acknowledge: AcknowledgeWeatherSafetyReviewUseCase(repository),
    networkInfo: network,
  );

  test('loads the review', () async {
    final cubit = create();

    await cubit.load();

    expect(cubit.state.status, OperatorSafetyReviewDetailStatus.ready);
    expect(cubit.state.review?.id, 7);
    await cubit.close();
  });

  test('a foreign review is reported as Safe 404 and shows nothing', () async {
    repository.failure = const NotFoundFailure();
    final cubit = create();

    await cubit.load();

    expect(cubit.state.status, OperatorSafetyReviewDetailStatus.notFound);
    expect(cubit.state.review, isNull);
    await cubit.close();
  });

  test('a 404 while refreshing also removes the visible review', () async {
    final cubit = create();
    await cubit.load();
    repository.failure = const NotFoundFailure();

    await cubit.load();

    expect(cubit.state.status, OperatorSafetyReviewDetailStatus.notFound);
    expect(cubit.state.review, isNull);
    await cubit.close();
  });

  test('a silent refresh keeps the review when the request fails', () async {
    final cubit = create();
    await cubit.load();
    repository.failure = const NetworkFailure();

    await cubit.load();

    expect(cubit.state.status, OperatorSafetyReviewDetailStatus.ready);
    expect(cubit.state.review?.id, 7);
    await cubit.close();
  });

  test('acknowledge stores the server state and trims instructions', () async {
    final cubit = create();
    await cubit.load();

    await cubit.acknowledgeReview(immediateInstructions: '  Keep indoors.  ');

    expect(repository.lastInstructions, 'Keep indoors.');
    expect(cubit.state.review?.status, WeatherSafetyReviewStatus.acknowledged);
    expect(cubit.state.isAcknowledging, isFalse);
    await cubit.close();
  });

  test('blank instructions are sent as absent', () async {
    final cubit = create();
    await cubit.load();

    await cubit.acknowledgeReview(immediateInstructions: '   ');

    expect(repository.lastInstructions, isNull);
    await cubit.close();
  });

  test('a double submit sends one request', () async {
    final cubit = create();
    await cubit.load();
    repository.gate = Completer<void>();

    final first = cubit.acknowledgeReview();
    final second = cubit.acknowledgeReview();
    await pumpEventQueue();
    expect(cubit.state.isAcknowledging, isTrue);
    repository.gate!.complete();
    await Future.wait([first, second]);

    expect(repository.acknowledgeCalls, 1);
    await cubit.close();
  });

  test('a replayed acknowledge is a normal success', () async {
    final cubit = create();
    await cubit.load();

    await cubit.acknowledgeReview();
    await cubit.acknowledgeReview();

    expect(cubit.state.actionFailure, isNull);
    expect(cubit.state.review?.status, WeatherSafetyReviewStatus.acknowledged);
    expect(repository.acknowledgeCalls, 1, reason: 'no longer acknowledgeable');
    await cubit.close();
  });

  test('offline does not send the acknowledge', () async {
    final cubit = create();
    await cubit.load();
    network.connected = false;

    await cubit.acknowledgeReview();

    expect(repository.acknowledgeCalls, 0);
    expect(cubit.state.actionFailure, isA<NetworkFailure>());
    await cubit.close();
  });

  test(
    'a closed review reports the failure and reloads server state',
    () async {
      final cubit = create();
      await cubit.load();
      repository
        ..acknowledgeFailure = const EmergencyTourFailure(
          'closed',
          reason: EmergencyTourFailureReason.reviewClosed,
        )
        ..reviewResult = review(status: WeatherSafetyReviewStatus.closed);

      await cubit.acknowledgeReview();

      expect(cubit.state.actionFailure, isA<EmergencyTourFailure>());
      expect(cubit.state.review?.status, WeatherSafetyReviewStatus.closed);
      await cubit.close();
    },
  );

  test(
    'a refresh during acknowledge cannot re-enable the button or undo it',
    () async {
      final cubit = create();
      await cubit.load();
      repository.gate = Completer<void>();
      final acknowledging = cubit.acknowledgeReview();
      await pumpEventQueue();

      final refreshing = cubit.load();
      await pumpEventQueue();
      expect(cubit.state.isAcknowledging, isTrue);

      repository.gate!.complete();
      await Future.wait([acknowledging, refreshing]);

      expect(
        cubit.state.review?.status,
        WeatherSafetyReviewStatus.acknowledged,
      );
      expect(cubit.state.isAcknowledging, isFalse);
      await cubit.close();
    },
  );

  test('a failed refresh labels the visible review as out of date', () async {
    final cubit = create();
    await cubit.load();
    repository.failure = const NetworkFailure();

    await cubit.load();

    expect(cubit.state.isStale, isTrue);
    expect(cubit.state.review?.id, 7);

    repository.failure = null;
    await cubit.load();
    expect(cubit.state.isStale, isFalse);
    await cubit.close();
  });

  test('reconnecting refreshes the review', () async {
    final cubit = create();
    await cubit.load();
    final before = repository.getReviewCalls;

    network.change(true);
    await pumpEventQueue();

    expect(repository.getReviewCalls, before + 1);
    await cubit.close();
  });

  test('losing the connection labels the review as out of date', () async {
    final cubit = create();
    await cubit.load();

    network.change(false);
    await pumpEventQueue();

    expect(cubit.state.isStale, isTrue);
    await cubit.close();
  });

  test('a hint for this review refreshes it, others do not', () async {
    final hints = StreamController<WeatherSafetyReviewHint>.broadcast();
    addTearDown(hints.close);
    final cubit = OperatorSafetyReviewDetailCubit(
      reviewId: 7,
      getReview: GetWeatherSafetyReviewUseCase(repository),
      acknowledge: AcknowledgeWeatherSafetyReviewUseCase(repository),
      networkInfo: network,
      hints: hints.stream,
    );
    await cubit.load();
    final before = repository.getReviewCalls;
    WeatherSafetyReviewHint hint(int id) => WeatherSafetyReviewHint(
      reviewId: id,
      changeType: 'Updated',
      occurredAtUtc: DateTime.utc(2026, 11, 9),
    );

    hints.add(hint(8));
    await pumpEventQueue();
    expect(repository.getReviewCalls, before);

    hints.add(hint(7));
    await pumpEventQueue();
    expect(repository.getReviewCalls, before + 1);
    await cubit.close();
  });

  test('a stale closure cannot emit after close', () async {
    repository.gate = Completer<void>();
    final cubit = create();
    final loading = cubit.load();
    await cubit.close();

    repository.gate!.complete();

    await expectLater(loading, completes);
  });
}
