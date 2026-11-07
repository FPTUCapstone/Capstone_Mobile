import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_realtime.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_state.dart';

import '../support/fake_operator_weather_safety_repository.dart';

void main() {
  late FakeOperatorWeatherSafetyRepository repository;
  late FakeNetworkInfo network;
  late FakeRealtime realtime;

  setUp(() {
    repository = FakeOperatorWeatherSafetyRepository();
    network = FakeNetworkInfo();
    realtime = FakeRealtime();
  });

  OperatorSafetyReviewsCubit create() => OperatorSafetyReviewsCubit(
    getReviews: GetWeatherSafetyReviewsUseCase(repository),
    networkInfo: network,
    realtime: realtime,
  );

  group('inbox', () {
    test(
      'loads reviews and counts pending and escalated for the badge',
      () async {
        repository.reviews = [
          review(id: 4),
          review(id: 3, status: WeatherSafetyReviewStatus.escalated),
          review(id: 2, status: WeatherSafetyReviewStatus.acknowledged),
          review(id: 1, status: WeatherSafetyReviewStatus.closed),
        ];
        final cubit = create();

        await cubit.refresh();

        expect(cubit.state.status, OperatorSafetyReviewsStatus.ready);
        expect(cubit.state.badgeCount, 2);
        expect(cubit.state.visibleReviews.map((item) => item.id), [4, 3, 2, 1]);
        await cubit.close();
      },
    );

    test('filters without changing the badge or refetching', () async {
      repository.reviews = [
        review(id: 4),
        review(id: 2, status: WeatherSafetyReviewStatus.acknowledged),
      ];
      final cubit = create();
      await cubit.refresh();

      cubit.setFilter(WeatherSafetyReviewStatus.acknowledged);

      expect(cubit.state.visibleReviews.map((item) => item.id), [2]);
      expect(cubit.state.badgeCount, 1);
      expect(repository.getReviewsCalls, 1);
      cubit.setFilter(null);
      expect(cubit.state.visibleReviews, hasLength(2));
      await cubit.close();
    });

    test(
      'a failed first load surfaces the failure and retry recovers',
      () async {
        repository.failure = const ServerFailure();
        final cubit = create();

        await cubit.refresh();
        expect(cubit.state.status, OperatorSafetyReviewsStatus.failure);
        expect(cubit.state.failure, const ServerFailure());

        repository
          ..failure = null
          ..reviews = [review()];
        await cubit.refresh();
        expect(cubit.state.status, OperatorSafetyReviewsStatus.ready);
        expect(cubit.state.failure, isNull);
        await cubit.close();
      },
    );

    test('a silent refresh failure keeps the visible list', () async {
      repository.reviews = [review()];
      final cubit = create();
      await cubit.refresh();

      repository.failure = const ServerFailure();
      await cubit.refresh();

      expect(cubit.state.status, OperatorSafetyReviewsStatus.ready);
      expect(cubit.state.visibleReviews, hasLength(1));
      expect(cubit.state.isStale, isTrue);
      await cubit.close();
    });

    test('a silent refresh never returns to the loading state', () async {
      repository.reviews = [review()];
      final cubit = create();
      await cubit.refresh();
      final statuses = <OperatorSafetyReviewsStatus>[];
      final subscription = cubit.stream.listen(
        (state) => statuses.add(state.status),
      );

      await cubit.refresh();
      await pumpEventQueue();

      expect(statuses, isNot(contains(OperatorSafetyReviewsStatus.loading)));
      await subscription.cancel();
      await cubit.close();
    });

    test('offline shows the last list as stale without calling REST', () async {
      repository.reviews = [review()];
      final cubit = create();
      await cubit.refresh();
      network.connected = false;

      await cubit.refresh();

      expect(repository.getReviewsCalls, 1);
      expect(cubit.state.isStale, isTrue);
      expect(cubit.state.visibleReviews, hasLength(1));
      await cubit.close();
    });

    test('offline with nothing cached reports a network failure', () async {
      network.connected = false;
      final cubit = create();

      await cubit.refresh();

      expect(repository.getReviewsCalls, 0);
      expect(cubit.state.failure, isA<NetworkFailure>());
      await cubit.close();
    });

    test('concurrent refreshes share one request and one follow-up', () async {
      repository
        ..reviews = [review()]
        ..gate = Completer<void>();
      final cubit = create();

      final first = cubit.refresh();
      await pumpEventQueue();
      unawaited(cubit.refresh());
      unawaited(cubit.refresh());
      await pumpEventQueue();
      expect(repository.getReviewsCalls, 1);

      repository.gate!.complete();
      await first;
      await pumpEventQueue();

      expect(repository.getReviewsCalls, 2);
      await cubit.close();
    });

    test('reset clears the previous account data', () async {
      repository.reviews = [review()];
      final cubit = create();
      await cubit.refresh();
      cubit.setFilter(WeatherSafetyReviewStatus.closed);

      await cubit.reset();

      expect(cubit.state, const OperatorSafetyReviewsState());
      await cubit.close();
    });

    test('a response from before reset cannot restore old data', () async {
      repository
        ..reviews = [review()]
        ..gate = Completer<void>();
      final cubit = create();
      final inFlight = cubit.refresh();
      await pumpEventQueue();

      await cubit.reset();
      repository.gate!.complete();
      await inFlight;
      await pumpEventQueue();

      expect(cubit.state.visibleReviews, isEmpty);
      await cubit.close();
    });
  });

  group('realtime hints', () {
    test('a hint refreshes REST and never trusts the hint payload', () async {
      repository.reviews = [review()];
      final cubit = create();
      await cubit.startSession();
      await pumpEventQueue();
      final before = repository.getReviewsCalls;

      repository.reviews = [review(), review(id: 8)];
      realtime.hint(reviewId: 8, change: 'Created');
      await pumpEventQueue();

      expect(repository.getReviewsCalls, before + 1);
      expect(cubit.state.visibleReviews, hasLength(2));
      await cubit.close();
    });

    test('a duplicate hint does not refetch', () async {
      repository.reviews = [review()];
      final cubit = create();
      await cubit.startSession();
      await pumpEventQueue();
      final before = repository.getReviewsCalls;

      realtime.hint(reviewId: 8, change: 'Created');
      await pumpEventQueue();
      realtime.hint(reviewId: 8, change: 'Created');
      await pumpEventQueue();

      expect(repository.getReviewsCalls, before + 1);
      await cubit.close();
    });

    test('created then escalated are distinct changes', () async {
      repository.reviews = [review()];
      final cubit = create();
      await cubit.startSession();
      await pumpEventQueue();
      final before = repository.getReviewsCalls;

      realtime.hint(reviewId: 8, change: 'Created');
      await pumpEventQueue();
      realtime.hint(reviewId: 8, change: 'Escalated');
      await pumpEventQueue();

      expect(repository.getReviewsCalls, before + 2);
      await cubit.close();
    });

    test('reconnecting refreshes to recover missed hints', () async {
      repository.reviews = [review()];
      final cubit = create();
      await cubit.startSession();
      await pumpEventQueue();
      final before = repository.getReviewsCalls;

      realtime.setConnected(false);
      await pumpEventQueue();
      realtime.setConnected(true);
      await pumpEventQueue();

      expect(repository.getReviewsCalls, before + 1);
      await cubit.close();
    });

    test('backgrounding stops the connection and resuming refreshes', () async {
      repository.reviews = [review()];
      final cubit = create();
      await cubit.startSession();
      await pumpEventQueue();
      final before = repository.getReviewsCalls;

      await cubit.onBackground();
      expect(realtime.stops, 1);

      await cubit.onForeground();
      expect(realtime.starts, 2);
      expect(repository.getReviewsCalls, before + 1);
      await cubit.close();
    });

    test('reset stops the connection', () async {
      final cubit = create();
      await cubit.startSession();

      await cubit.reset();

      expect(realtime.stops, 1);
      await cubit.close();
    });

    test('a failed connection does not block the inbox', () async {
      repository.reviews = [review()];
      realtime.startFailure = StateError('hub unavailable');
      final cubit = create();

      await cubit.startSession();
      await pumpEventQueue();

      expect(cubit.state.status, OperatorSafetyReviewsStatus.ready);
      expect(cubit.state.visibleReviews, hasLength(1));
      await cubit.close();
    });
  });

  group('polling fallback', () {
    OperatorSafetyReviewsCubit started(FakeAsync async) {
      repository.reviews = [review()];
      final cubit = create();
      unawaited(cubit.startSession());
      async.flushMicrotasks();
      return cubit;
    }

    test('polls every 30 seconds only while visible and disconnected', () {
      fakeAsync((async) {
        final cubit = started(async);
        final before = repository.getReviewsCalls;

        async.elapse(const Duration(seconds: 90));
        expect(
          repository.getReviewsCalls,
          before,
          reason: 'connected: no poll',
        );

        realtime.setConnected(false);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 90));
        expect(repository.getReviewsCalls, before, reason: 'not visible');

        cubit.setInboxVisible(true);
        async.flushMicrotasks();
        final visibleBefore = repository.getReviewsCalls;
        async.elapse(const Duration(seconds: 30));
        expect(repository.getReviewsCalls, visibleBefore + 1);
        async.elapse(const Duration(seconds: 30));
        expect(repository.getReviewsCalls, visibleBefore + 2);

        cubit.setInboxVisible(false);
        final hiddenBefore = repository.getReviewsCalls;
        async.elapse(const Duration(seconds: 120));
        expect(repository.getReviewsCalls, hiddenBefore);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('reconnecting and backgrounding each stop the poll', () {
      fakeAsync((async) {
        final cubit = started(async);
        cubit.setInboxVisible(true);
        realtime.setConnected(false);
        async.flushMicrotasks();

        realtime.setConnected(true);
        async.flushMicrotasks();
        final connected = repository.getReviewsCalls;
        async.elapse(const Duration(seconds: 90));
        expect(repository.getReviewsCalls, connected);

        realtime.setConnected(false);
        async.flushMicrotasks();
        unawaited(cubit.onBackground());
        async.flushMicrotasks();
        final background = repository.getReviewsCalls;
        async.elapse(const Duration(seconds: 90));
        expect(repository.getReviewsCalls, background);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });
  });
}

final class FakeRealtime implements OperatorWeatherSafetyRealtime {
  final _hints = StreamController<WeatherSafetyReviewHint>.broadcast(
    sync: true,
  );
  final _connection = StreamController<bool>.broadcast(sync: true);
  int starts = 0;
  int stops = 0;
  Object? startFailure;

  void hint({required int reviewId, required String change}) => _hints.add(
    WeatherSafetyReviewHint(
      reviewId: reviewId,
      changeType: change,
      occurredAtUtc: DateTime.utc(2026, 11, 9, 8),
    ),
  );

  void setConnected(bool connected) => _connection.add(connected);

  @override
  Stream<WeatherSafetyReviewHint> get hints => _hints.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  Future<void> start() async {
    starts++;
    final failure = startFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> stop() async => stops++;
}
