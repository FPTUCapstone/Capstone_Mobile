import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/pending_explanation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_detail_page.dart';

const _template = 'Template sentence for the museum';
const _ai = 'AI sentence for the museum';

ItineraryDetail _detail(String sentence) => ItineraryDetail(
  itineraryId: 10,
  schedulingRequestId: 20,
  title: 'Day plan',
  version: 1,
  status: 'Draft',
  validFrom: DateTime.utc(2026, 9, 20, 1),
  validTo: DateTime.utc(2026, 9, 20, 9),
  canManage: false,
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
      recommendationReason: 'Reason that must never show next to the AI text',
      isUnavailable: false,
      friendlyExplanation: sentence,
    ),
  ],
);

/// Answers the first load with the template, then each later load with the
/// next sentence; the last one repeats.
final class _Repository implements ItineraryRepository {
  _Repository(this.sentences);

  final List<String> sentences;
  int getByIdCalls = 0;

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    getByIdCalls++;
    final sentence = sentences.length > 1
        ? sentences.removeAt(0)
        : sentences[0];
    return _detail(sentence);
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

Future<_Repository> _pump(
  WidgetTester tester,
  List<String> sentences, {
  PendingExplanation? pending,
}) async {
  final repository = _Repository(sentences);
  final cubit = ItineraryDetailCubit(repository: repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: ItineraryDetailPage(
          itineraryId: 10,
          pendingExplanation: pending,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repository;
}

PendingExplanation _pending({int itineraryId = 10}) => PendingExplanation(
  itineraryId: itineraryId,
  createdAt: DateTime.now(),
  template: const {1: _template},
);

void main() {
  testWidgets('shows the AI sentence once it arrives and stops loading', (
    tester,
  ) async {
    final repository = await _pump(tester, [
      _template,
      _template,
      _ai,
    ], pending: _pending());
    expect(find.text(_template), findsOneWidget);
    expect(repository.getByIdCalls, 1);

    await tester.pump(const Duration(seconds: 21));
    expect(repository.getByIdCalls, 2);
    expect(find.text(_template), findsOneWidget);

    await tester.pump(const Duration(seconds: 25));
    await tester.pump();
    expect(repository.getByIdCalls, 3);
    expect(find.text(_ai), findsOneWidget);
    expect(find.text(_template), findsNothing);
    expect(find.textContaining('Reason that must never show'), findsNothing);

    await tester.pump(const Duration(seconds: 200));
    expect(repository.getByIdCalls, 3);
  });

  testWidgets('makes no extra request without a pending explanation', (
    tester,
  ) async {
    final repository = await _pump(tester, [_ai]);

    await tester.pump(const Duration(seconds: 200));

    expect(repository.getByIdCalls, 1);
    expect(find.text(_ai), findsOneWidget);
  });

  testWidgets('ignores a pending explanation of another itinerary', (
    tester,
  ) async {
    final repository = await _pump(tester, [
      _template,
    ], pending: _pending(itineraryId: 99));

    await tester.pump(const Duration(seconds: 200));

    expect(repository.getByIdCalls, 1);
  });
}
