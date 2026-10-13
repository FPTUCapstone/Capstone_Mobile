import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_detail_page.dart';

void main() {
  testWidgets('owner sees persisted timeline and owner actions', (
    tester,
  ) async {
    final cubit = ItineraryDetailCubit(repository: _Repository(_ownerDetail));
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

    expect(find.text('Day plan'), findsOneWidget);
    expect(find.text('Accept itinerary'), findsOneWidget);
    expect(find.text('Reorder or remove places'), findsOneWidget);
    expect(find.text('This place is currently unavailable.'), findsOneWidget);
    expect(find.text('Travel: 15 min'), findsOneWidget);

    await tester.tap(find.text('Reorder or remove places'));
    await tester.pumpAndSettle();

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.onReorderItem, isNotNull);
  });

  testWidgets('timeline keeps Vietnam itinerary time instead of device time', (
    tester,
  ) async {
    final cubit = ItineraryDetailCubit(repository: _Repository(_ownerDetail));
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

    expect(find.text('08:00'), findsOneWidget);
  });

  testWidgets(
    'saving a reordered timeline submits POI IDs in displayed order',
    (tester) async {
      final repository = _Repository(_ownerDetail);
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
      await tester.tap(find.text('Reorder or remove places'));
      await tester.pumpAndSettle();

      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorderItem!(0, 1);
      await tester.pump();
      await tester.tap(find.text('Save adjustment'));
      await tester.pumpAndSettle();

      expect(repository.adjustedOrders, [
        [102, 101],
      ]);
    },
  );

  testWidgets('group member sees the timeline without owner actions', (
    tester,
  ) async {
    final cubit = ItineraryDetailCubit(repository: _Repository(_memberDetail));
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

    expect(find.text('Read-only access (Group member)'), findsOneWidget);
    expect(find.text('Accept itinerary'), findsNothing);
    expect(find.text('Reorder or remove places'), findsNothing);
    expect(find.byTooltip('Regenerate itinerary'), findsNothing);
  });

  testWidgets(
    'forbidden detail load explains that the itinerary is inaccessible',
    (tester) async {
      final cubit = ItineraryDetailCubit(
        repository: _Repository(_ownerDetail, const PermissionFailure()),
      );
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

      expect(
        find.text('You do not have access to this itinerary.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('missing detail load shows a not-found message', (tester) async {
    final cubit = ItineraryDetailCubit(
      repository: _Repository(_ownerDetail, const NotFoundFailure()),
    );
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

    expect(find.text('This itinerary could not be found.'), findsOneWidget);
  });

  testWidgets(
    'commercial stop renders action button with CommercialServiceEn label',
    (tester) async {
      final commercialItinerary = ItineraryDetail(
        itineraryId: 12,
        schedulingRequestId: 25,
        title: 'Commercial Plan',
        version: 1,
        status: 'Active',
        validFrom: DateTime.utc(2026, 9, 20, 1),
        validTo: DateTime.utc(2026, 9, 20, 5),
        canManage: true,
        totalEstimatedCost: 100_000,
        totalDurationMinutes: 180,
        items: [
          ItineraryDetailItem(
            itemId: 3,
            sequenceNo: 1,
            poiId: 105,
            poiName: 'Han River Hotel',
            category: 'Hotel',
            itemKind: ItineraryItemKind.visit,
            plannedArrival: DateTime.utc(2026, 9, 20, 1),
            plannedDeparture: DateTime.utc(2026, 9, 20, 2),
            travelDurationFromPreviousMinutes: null,
            stayDurationMinutes: 60,
            estimatedCost: 100_000,
            isMandatory: false,
            recommendationReason: 'Commercial stop',
            isUnavailable: false,
          ),
          ItineraryDetailItem(
            itemId: 4,
            sequenceNo: 2,
            poiId: 106,
            poiName: 'Non-commercial Beach',
            category: 'Natural attraction',
            itemKind: ItineraryItemKind.visit,
            plannedArrival: DateTime.utc(2026, 9, 20, 2, 15),
            plannedDeparture: DateTime.utc(2026, 9, 20, 3, 15),
            travelDurationFromPreviousMinutes: 15,
            stayDurationMinutes: 60,
            estimatedCost: null,
            isMandatory: false,
            recommendationReason: 'Beach stop',
            isUnavailable: false,
          ),
        ],
      );

      final cubit = ItineraryDetailCubit(
        repository: _Repository(commercialItinerary),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const ItineraryDetailPage(itineraryId: 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Commercial item renders button with CommercialServiceEn label
      expect(
        find.byKey(const Key('itinerary_item_commercial_service_3')),
        findsOneWidget,
      );
      expect(
        find.text(CommercialServiceEn.entryPoints.viewServiceButton),
        findsOneWidget,
      );

      // Non-commercial stop does not render commercial action button
      expect(
        find.byKey(const Key('itinerary_item_commercial_service_4')),
        findsNothing,
      );
    },
  );
}

final _ownerDetail = ItineraryDetail(
  itineraryId: 10,
  schedulingRequestId: 20,
  title: 'Day plan',
  version: 1,
  status: 'Draft',
  validFrom: DateTime.utc(2026, 9, 20, 1),
  validTo: DateTime.utc(2026, 9, 20, 5),
  canManage: true,
  totalEstimatedCost: 50_000,
  totalDurationMinutes: 240,
  items: [
    ItineraryDetailItem(
      itemId: 1,
      sequenceNo: 1,
      poiId: 101,
      poiName: 'Unavailable museum',
      category: 'Museum',
      itemKind: ItineraryItemKind.visit,
      plannedArrival: DateTime.utc(2026, 9, 20, 1),
      plannedDeparture: DateTime.utc(2026, 9, 20, 2),
      travelDurationFromPreviousMinutes: null,
      stayDurationMinutes: 60,
      estimatedCost: 50_000,
      isMandatory: false,
      recommendationReason: 'Suggested location',
      isUnavailable: true,
    ),
    ItineraryDetailItem(
      itemId: 2,
      sequenceNo: 2,
      poiId: 102,
      poiName: 'Beach',
      category: 'Natural attraction',
      itemKind: ItineraryItemKind.visit,
      plannedArrival: DateTime.utc(2026, 9, 20, 2, 15),
      plannedDeparture: DateTime.utc(2026, 9, 20, 3, 15),
      travelDurationFromPreviousMinutes: 15,
      stayDurationMinutes: 60,
      estimatedCost: null,
      isMandatory: false,
      recommendationReason: 'Suggested location',
      isUnavailable: false,
    ),
  ],
);

final _memberDetail = ItineraryDetail(
  itineraryId: _ownerDetail.itineraryId,
  schedulingRequestId: _ownerDetail.schedulingRequestId,
  title: _ownerDetail.title,
  version: _ownerDetail.version,
  status: 'Active',
  validFrom: _ownerDetail.validFrom,
  validTo: _ownerDetail.validTo,
  canManage: false,
  totalEstimatedCost: _ownerDetail.totalEstimatedCost,
  totalDurationMinutes: _ownerDetail.totalDurationMinutes,
  items: _ownerDetail.items,
);

final class _Repository implements ItineraryRepository {
  _Repository(this.detail, [this.failure]);

  final ItineraryDetail detail;
  final Failure? failure;
  final adjustedOrders = <List<int>>[];

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    if (failure != null) throw failure!;
    return detail;
  }

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> adjustItems({
    required int itineraryId,
    required List<int> orderedVisitPoiIds,
    required String idempotencyKey,
  }) async {
    adjustedOrders.add(List<int>.from(orderedVisitPoiIds));
    return detail;
  }
}
