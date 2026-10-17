import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_detail_page.dart';

/// Review 2 behaviour of the itinerary detail page: prices, legs, transport
/// changes, change badges and undo.
void main() {
  Future<EditRepository> pump(
    WidgetTester tester,
    ItineraryDetail detail, {
    List<ItineraryDetail> updates = const [],
    Failure? updateFailure,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = EditRepository(detail)
      ..updatedDetails.addAll(updates)
      ..updateFailure = updateFailure;
    final cubit = ItineraryDetailCubit(repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const ItineraryDetailPage(itineraryId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('shows honest per-stop prices and the cost split', (
    tester,
  ) async {
    await pump(tester, editablePlan());

    expect(find.text('Giá vé dự kiến: 60.000 VNĐ/người'), findsOneWidget);
    expect(find.text('Mức chi tiêu dự kiến: 85.000 VNĐ/người'), findsOneWidget);
    expect(find.text('Chưa có thông tin'), findsOneWidget);
    final summary = find.byKey(const Key('cost_summary'));
    expect(
      find.descendant(of: summary, matching: find.text('60.000 VNĐ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('85.000 VNĐ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('145.000 VNĐ')),
      findsOneWidget,
    );
    // The beach has no known price: the total says so instead of treating it
    // as free.
    expect(
      find.descendant(
        of: summary,
        matching: find.text('Chưa tính 1 điểm chưa có giá'),
      ),
      findsOneWidget,
    );
    expect(find.text('Điểm bắt buộc'), findsOneWidget);
    expect(find.text('60 phút'), findsWidgets);
  });

  testWidgets('the total is compared with the budget when there is one', (
    tester,
  ) async {
    await pump(tester, editablePlan(budgetVnd: 800000));

    final summary = find.byKey(const Key('cost_summary'));
    expect(
      find.descendant(of: summary, matching: find.text('Tổng / ngân sách')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.text('145.000 VNĐ / 800.000 VNĐ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a budget only the total is shown', (tester) async {
    await pump(tester, editablePlan());

    expect(find.textContaining('ngân sách'), findsNothing);
  });

  testWidgets('legs show distance, time and transport', (tester) async {
    await pump(tester, editablePlan());

    expect(find.text('9,4 km · khoảng 22 phút · Xe máy'), findsOneWidget);
    expect(find.text('600 m · khoảng 3 phút · Xe máy'), findsOneWidget);
    expect(find.text('Gần, có thể đi bộ ~8 phút'), findsOneWidget);
    // Shown once, not per leg.
    expect(find.byKey(const Key('motorbike_note')), findsOneWidget);
    expect(find.text('Đổi'), findsNWidgets(2));
  });

  testWidgets('controls are labelled for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      editablePlan(),
      updates: [editablePlan(version: 2, beachDelayMinutes: 25)],
    );

    expect(
      find.bySemanticsLabel('Đổi phương tiện đến My Khe Beach'),
      findsOneWidget,
    );
    expect(find.byTooltip('Tùy chọn cho Cham Museum'), findsOneWidget);

    await tester.tap(find.text('Đổi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đi bộ'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Giờ đến lùi 25 phút'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('⟲')), findsNothing);
    semantics.dispose();
  });

  testWidgets('a leg without a known distance hides the km', (tester) async {
    await pump(tester, editablePlan(firstLegMeters: null));

    expect(find.text('khoảng 22 phút · Xe máy'), findsOneWidget);
  });

  testWidgets('changing a leg to walking saves every stop', (tester) async {
    final repository = await pump(
      tester,
      editablePlan(),
      updates: [editablePlan(version: 2, beachDelayMinutes: 25)],
    );

    await tester.tap(find.text('Đổi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đi bộ'));
    await tester.pumpAndSettle();

    expect(repository.sentStops.single, const [
      ItineraryStop(poiId: 1, transportModeToNext: TransportMode.walking),
      ItineraryStop(poiId: 2, transportModeToNext: TransportMode.motorbike),
      ItineraryStop(poiId: 3),
    ]);
    expect(find.text('⟲ lùi 25 phút'), findsWidgets);
    expect(find.text('Hoàn tác'), findsOneWidget);

    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();

    expect(repository.sentStops, hasLength(2));
    expect(repository.sentStops.last, const [
      ItineraryStop(poiId: 1, transportModeToNext: TransportMode.motorbike),
      ItineraryStop(poiId: 2, transportModeToNext: TransportMode.motorbike),
      ItineraryStop(poiId: 3),
    ]);
  });

  testWidgets('a stop that does not fit is explained', (tester) async {
    await pump(
      tester,
      editablePlan(),
      updateFailure: const StopInfeasibleFailure(
        poiId: 3,
        reason: 'ClosedAtArrival',
        closesAt: '16:30',
      ),
    );

    await tester.tap(find.text('Đổi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đi bộ'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Không thể lưu: Noodle house đã đóng cửa khi đến nơi '
        '(đóng cửa lúc 16:30).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('no transport change while the trip is being navigated', (
    tester,
  ) async {
    await pump(tester, editablePlan(navigating: true));

    expect(find.text('9,4 km · khoảng 22 phút · Xe máy'), findsOneWidget);
    expect(find.text('Đổi'), findsNothing);
  });

  testWidgets(
    'legs leading to or from a Rest stop hide the change button and walk hint',
    (tester) async {
      DateTime vn(int hour, int minute) =>
          DateTime.utc(2026, 10, 18, hour - 7, minute);

      await pump(
        tester,
        editablePlan(
          items: [
            planItem(1, 'Visit 1', vn(8, 0)),
            planItem(
              2,
              'Rest Stop',
              vn(9, 0),
              travelMinutes: 10,
              meters: 500,
              mode: TransportMode.motorbike,
              kind: ItineraryItemKind.rest,
            ),
            planItem(
              3,
              'Visit 2',
              vn(10, 0),
              travelMinutes: 15,
              meters: 600,
              mode: TransportMode.motorbike,
            ),
          ],
        ),
      );

      expect(find.text('Đổi'), findsNothing);
      expect(find.textContaining('Gần, có thể đi bộ'), findsNothing);
    },
  );
}

/// Three stops (Vietnam time 08:00, 09:22, 10:25): museum, beach, noodle house.
ItineraryDetail editablePlan({
  int version = 1,
  bool navigating = false,
  int? firstLegMeters = 9400,
  int beachDelayMinutes = 0,
  bool canManage = true,
  List<ItineraryDetailItem>? items,
  DateTime? validTo,
  double? budgetVnd,
}) {
  DateTime vn(int hour, int minute) =>
      DateTime.utc(2026, 10, 18, hour - 7, minute);
  final beach = vn(9, 22).add(Duration(minutes: beachDelayMinutes));
  return ItineraryDetail(
    itineraryId: 10,
    schedulingRequestId: 20,
    title: 'Day plan',
    version: version,
    status: 'Draft',
    validFrom: vn(8, 0),
    validTo: validTo ?? vn(11, 0),
    canManage: canManage,
    totalEstimatedCost: 145000,
    totalDurationMinutes: 180,
    isNavigationInProgress: navigating,
    transportMode: TransportMode.motorbike,
    budgetVnd: budgetVnd,
    items:
        items ??
        [
          planItem(
            1,
            'Cham Museum',
            vn(8, 0),
            cost: 60000,
            costKind: CostKind.admissionTicket,
            isMandatory: true,
          ),
          planItem(
            2,
            'My Khe Beach',
            beach,
            travelMinutes: 22,
            meters: firstLegMeters,
            mode: TransportMode.motorbike,
            costKind: CostKind.admissionTicket,
          ),
          planItem(
            3,
            'Noodle house',
            beach.add(const Duration(minutes: 63)),
            travelMinutes: 3,
            meters: 600,
            mode: TransportMode.motorbike,
            cost: 85000,
            costKind: CostKind.averageSpend,
          ),
        ],
  );
}

ItineraryDetailItem planItem(
  int poiId,
  String name,
  DateTime arrival, {
  int? travelMinutes,
  int? meters,
  TransportMode? mode,
  double? cost,
  CostKind? costKind,
  bool isMandatory = false,
  int stay = 60,
  ItineraryItemKind kind = ItineraryItemKind.visit,
}) => ItineraryDetailItem(
  itemId: poiId * 10,
  sequenceNo: poiId,
  poiId: poiId,
  poiName: name,
  category: costKind == CostKind.averageSpend ? 'Food & Drink' : 'Museum',
  itemKind: kind,
  plannedArrival: arrival,
  plannedDeparture: arrival.add(Duration(minutes: stay)),
  travelDurationFromPreviousMinutes: travelMinutes,
  stayDurationMinutes: stay,
  estimatedCost: cost,
  isMandatory: isMandatory,
  recommendationReason: null,
  isUnavailable: false,
  travelDistanceFromPreviousMeters: meters,
  transportModeFromPrevious: mode,
  costKind: costKind,
  latitude: 16.0 + poiId / 100,
  longitude: 108.2 + poiId / 100,
);

final class EditRepository implements ItineraryRepository {
  EditRepository(this.detail);

  final ItineraryDetail detail;
  final sentStops = <List<ItineraryStop>>[];
  final updatedDetails = <ItineraryDetail>[];
  Failure? updateFailure;
  int regenerateCalls = 0;

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> getById(int itineraryId) async => detail;

  @override
  Future<ItineraryDetail> accept(int itineraryId) async => detail;

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) async {
    regenerateCalls++;
    return detail;
  }

  @override
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
  }) async {
    sentStops.add(stops);
    if (updateFailure case final failure?) throw failure;
    return updatedDetails.isEmpty ? detail : updatedDetails.removeAt(0);
  }
}
