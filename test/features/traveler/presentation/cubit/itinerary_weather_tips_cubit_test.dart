import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_weather_tips_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_weather_tips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_weather_tips_state.dart';

ItineraryWeatherTips _tips(String date) => ItineraryWeatherTips(
  date: date,
  timeZoneId: 'Asia/Ho_Chi_Minh',
  forecastAtUtc: DateTime.utc(2026, 11, 24, 3),
  summary: const WeatherTipsSummary(
    minTempC: 22,
    maxTempC: 31,
    maxRainProbabilityPercent: 60,
    maxUvIndex: 8,
  ),
  tips: const [
    WeatherTip(
      code: 'weather_tip.rain',
      severity: WeatherTipSeverity.info,
      text: 'Mang ô hoặc áo mưa',
    ),
  ],
);

final class _Repository implements ItineraryWeatherTipsRepository {
  final calls = <int>[];
  final _answers = <int, Completer<ItineraryWeatherTips?>>{};
  Object? failure;

  Completer<ItineraryWeatherTips?> answerFor(int id) =>
      _answers.putIfAbsent(id, Completer.new);

  @override
  Future<ItineraryWeatherTips?> getWeatherTips(int itineraryId) {
    calls.add(itineraryId);
    if (failure case final failure?) throw failure;
    return answerFor(itineraryId).future;
  }
}

void main() {
  late _Repository repository;
  late ItineraryWeatherTipsCubit cubit;
  late List<ItineraryWeatherTipsState> emitted;
  late StreamSubscription<ItineraryWeatherTipsState> subscription;

  setUp(() {
    repository = _Repository();
    cubit = ItineraryWeatherTipsCubit(repository: repository);
    emitted = [];
    subscription = cubit.stream.listen(emitted.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await cubit.close();
  });

  test('starts without tips', () {
    expect(cubit.state.tips, isNull);
  });

  test('emits the tips when the repository answers', () async {
    final done = cubit.load(10);
    repository.answerFor(10).complete(_tips('2026-11-25'));
    await done;
    await pumpEventQueue();

    expect(emitted, [ItineraryWeatherTipsState(tips: _tips('2026-11-25'))]);
  });

  test('emits nothing when the answer is null', () async {
    final done = cubit.load(10);
    repository.answerFor(10).complete(null);
    await done;

    await pumpEventQueue();
    expect(emitted, isEmpty);
    expect(cubit.state.tips, isNull);
  });

  test('emits nothing when the repository throws', () async {
    repository.failure = StateError('boom');

    await cubit.load(10);

    await pumpEventQueue();
    expect(emitted, isEmpty);
    expect(cubit.state.tips, isNull);
  });

  test('asks once per id, also while the first answer is pending', () async {
    final first = cubit.load(10);
    final second = cubit.load(10);
    repository.answerFor(10).complete(_tips('2026-11-25'));
    await Future.wait([first, second]);

    expect(repository.calls, [10]);
  });

  test('does not ask again for the same id after a null answer', () async {
    final first = cubit.load(10);
    repository.answerFor(10).complete(null);
    await first;

    await cubit.load(10);

    expect(repository.calls, [10]);
  });

  test('does not ask when there is no repository', () async {
    final silent = ItineraryWeatherTipsCubit(repository: null);
    addTearDown(silent.close);
    final states = <ItineraryWeatherTipsState>[];
    final sub = silent.stream.listen(states.add);
    addTearDown(sub.cancel);

    await silent.load(10);

    await pumpEventQueue();
    expect(states, isEmpty);
    expect(silent.state.tips, isNull);
  });

  test(
    'clears the tips of the previous itinerary when the id changes',
    () async {
      final first = cubit.load(10);
      repository.answerFor(10).complete(_tips('2026-11-25'));
      await first;

      final second = cubit.load(11);

      expect(cubit.state.tips, isNull);
      repository.answerFor(11).complete(null);
      await second;
    },
  );

  test('ignores a late answer for the previous id', () async {
    final first = cubit.load(10);
    final second = cubit.load(11);
    repository.answerFor(11).complete(_tips('2026-12-01'));
    await second;
    repository.answerFor(10).complete(_tips('2026-11-25'));
    await first;

    expect(cubit.state.tips?.date, '2026-12-01');
  });

  test('does not emit after close', () async {
    final done = cubit.load(10);
    await cubit.close();
    repository.answerFor(10).complete(_tips('2026-11-25'));

    await done;

    await pumpEventQueue();
    expect(emitted, isEmpty);
  });
}
