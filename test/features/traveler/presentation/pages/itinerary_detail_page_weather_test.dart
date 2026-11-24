import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_weather_tips_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_detail_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_cost_summary.dart';

final _tips = ItineraryWeatherTips(
  date: '2026-09-20',
  timeZoneId: 'Asia/Ho_Chi_Minh',
  forecastAtUtc: DateTime.utc(2026, 9, 19, 3),
  summary: const WeatherTipsSummary(
    minTempC: 24,
    maxTempC: 32,
    maxRainProbabilityPercent: 70,
    maxUvIndex: 9,
  ),
  tips: const [
    WeatherTip(
      code: 'weather_tip.rain',
      severity: WeatherTipSeverity.info,
      text: 'Mang ô hoặc áo mưa',
    ),
  ],
);

ItineraryDetail _detail() => ItineraryDetail(
  itineraryId: 10,
  schedulingRequestId: 20,
  title: 'Day plan',
  version: 1,
  status: 'Draft',
  validFrom: DateTime.utc(2026, 9, 20, 1),
  validTo: DateTime.utc(2026, 9, 20, 9),
  canManage: true,
  totalEstimatedCost: 0,
  totalDurationMinutes: 60,
  items: [
    ItineraryDetailItem(
      itemId: 1,
      sequenceNo: 1,
      poiId: 7,
      poiName: 'Museum',
      category: 'Museum',
      itemKind: ItineraryItemKind.visit,
      plannedArrival: DateTime.utc(2026, 9, 20, 1),
      plannedDeparture: DateTime.utc(2026, 9, 20, 2),
      travelDurationFromPreviousMinutes: null,
      stayDurationMinutes: 60,
      estimatedCost: null,
      isMandatory: false,
      recommendationReason: 'A reason',
      isUnavailable: false,
    ),
  ],
);

final class _Repository implements ItineraryRepository {
  int getByIdCalls = 0;

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    getByIdCalls++;
    return _detail();
  }

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
    Map<int, StopRemovalReason> removalReasons = const {},
  }) => throw UnimplementedError();
}

final class _WeatherRepository implements ItineraryWeatherTipsRepository {
  _WeatherRepository({this.failure});

  final Object? failure;
  final calls = <int>[];
  final answer = Completer<ItineraryWeatherTips?>();

  @override
  Future<ItineraryWeatherTips?> getWeatherTips(int itineraryId) {
    calls.add(itineraryId);
    if (failure case final failure?) throw failure;
    return answer.future;
  }
}

Future<(_Repository, ItineraryDetailCubit)> _pump(
  WidgetTester tester,
  _WeatherRepository weather,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = _Repository();
  final cubit = ItineraryDetailCubit(repository: repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: ItineraryDetailPage(
          itineraryId: 10,
          weatherTipsRepository: weather,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (repository, cubit);
}

final _card = find.byKey(const Key('itinerary_weather_tips_card'));

void main() {
  testWidgets(
    'shows the weather card after the cost summary and above the first stop',
    (tester) async {
      final weather = _WeatherRepository();
      await _pump(tester, weather);
      weather.answer.complete(_tips);
      await tester.pump();
      await tester.pump();

      expect(_card, findsOneWidget);
      expect(find.text('Thời tiết ngày 20/09'), findsOneWidget);
      final cost = tester.getTopLeft(find.byType(ItineraryCostSummary)).dy;
      final card = tester.getTopLeft(_card).dy;
      final stop = tester.getTopLeft(find.text('Museum').first).dy;
      expect(cost, lessThan(card));
      expect(card, lessThan(stop));
    },
  );

  testWidgets('shows no card when the repository answers null', (tester) async {
    final weather = _WeatherRepository();
    await _pump(tester, weather);
    weather.answer.complete(null);
    await tester.pump();

    expect(_card, findsNothing);
    expect(find.text('Museum'), findsWidgets);
  });

  testWidgets(
    'shows no card and still lists the stops when the repository throws',
    (tester) async {
      final weather = _WeatherRepository(failure: StateError('boom'));
      await _pump(tester, weather);

      expect(weather.calls, [10]);
      expect(_card, findsNothing);
      expect(find.text('Museum'), findsWidgets);
    },
  );

  testWidgets('shows no card while the weather answer is pending', (
    tester,
  ) async {
    final weather = _WeatherRepository();
    await _pump(tester, weather);

    expect(weather.calls, [10]);
    expect(_card, findsNothing);
    expect(find.text('Museum'), findsWidgets);
  });

  testWidgets('asks for the weather once, with the itinerary id', (
    tester,
  ) async {
    final weather = _WeatherRepository();
    await _pump(tester, weather);
    weather.answer.complete(_tips);
    await tester.pump();
    await tester.pump();

    expect(weather.calls, [10]);
  });

  testWidgets('does not ask again after the detail is reloaded', (
    tester,
  ) async {
    final weather = _WeatherRepository();
    final (repository, cubit) = await _pump(tester, weather);
    weather.answer.complete(_tips);
    await tester.pump();
    await tester.pump();
    expect(repository.getByIdCalls, 1);

    await cubit.load(10);
    await tester.pump();

    expect(repository.getByIdCalls, 2);
    expect(weather.calls, [10]);
    expect(_card, findsOneWidget);
  });

  testWidgets('the owner can still regenerate when the weather failed', (
    tester,
  ) async {
    final weather = _WeatherRepository(failure: StateError('boom'));
    await _pump(tester, weather);

    expect(find.byTooltip('Tạo lại lịch trình'), findsOneWidget);
  });
}
