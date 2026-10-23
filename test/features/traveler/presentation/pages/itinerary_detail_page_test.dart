import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
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
    expect(find.text('Địa điểm này hiện không hoạt động.'), findsOneWidget);
    expect(find.text('khoảng 15 phút'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sắp xếp hoặc bỏ địa điểm'), 200);
    expect(find.text('Chấp nhận lịch trình'), findsOneWidget);
    expect(find.text('Sắp xếp hoặc bỏ địa điểm'), findsOneWidget);

    await tester.ensureVisible(find.text('Sắp xếp hoặc bỏ địa điểm'));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Sắp xếp hoặc bỏ địa điểm'));
    await tester.pumpAndSettle();

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.onReorderItem, isNotNull);
  });

  testWidgets('owner cannot change a trip that is being navigated', (
    tester,
  ) async {
    final navigated = ItineraryDetail(
      itineraryId: _ownerDetail.itineraryId,
      schedulingRequestId: _ownerDetail.schedulingRequestId,
      title: _ownerDetail.title,
      version: _ownerDetail.version,
      status: 'Active',
      validFrom: _ownerDetail.validFrom,
      validTo: _ownerDetail.validTo,
      canManage: true,
      totalEstimatedCost: _ownerDetail.totalEstimatedCost,
      totalDurationMinutes: _ownerDetail.totalDurationMinutes,
      items: _ownerDetail.items,
      isNavigationInProgress: true,
    );
    final cubit = ItineraryDetailCubit(repository: _Repository(navigated));
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('navigation_in_progress_notice')),
      200,
    );

    expect(
      find.byKey(const Key('navigation_in_progress_notice')),
      findsOneWidget,
    );
    expect(find.text('Sắp xếp hoặc bỏ địa điểm'), findsNothing);
    expect(find.byTooltip('Tạo lại lịch trình'), findsNothing);
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
      await tester.scrollUntilVisible(
        find.text('Sắp xếp hoặc bỏ địa điểm'),
        200,
      );
      await tester.ensureVisible(find.text('Sắp xếp hoặc bỏ địa điểm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sắp xếp hoặc bỏ địa điểm'));
      await tester.pumpAndSettle();

      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorderItem!(0, 1);
      await tester.pump();
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(repository.sentStops, [
        const [ItineraryStop(poiId: 102), ItineraryStop(poiId: 101)],
      ]);
    },
  );

  testWidgets('draft itinerary asks for acceptance before navigation', (
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

    expect(find.text('Bắt đầu dẫn đường'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Chấp nhận lịch trình để bắt đầu dẫn đường.'),
      200,
    );
    expect(
      find.text('Chấp nhận lịch trình để bắt đầu dẫn đường.'),
      findsOneWidget,
    );
  });

  testWidgets('active itinerary starts navigation for this itinerary', (
    tester,
  ) async {
    final cubit = ItineraryDetailCubit(repository: _Repository(_memberDetail));
    addTearDown(cubit.close);
    Object? openedExtra;
    final router = GoRouter(
      initialLocation: '/traveler/itineraries/10',
      routes: [
        GoRoute(
          path: '/traveler/itineraries/:itineraryId',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const ItineraryDetailPage(itineraryId: 10),
          ),
        ),
        GoRoute(
          path: '/traveler/trips/:itineraryId/live',
          builder: (_, state) {
            openedExtra = state.extra;
            return Text('Live trip ${state.pathParameters['itineraryId']}');
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(
      find.text('Chấp nhận lịch trình để bắt đầu dẫn đường.'),
      findsNothing,
    );
    await tester.scrollUntilVisible(find.text('Bắt đầu dẫn đường'), 200);
    await tester.tap(find.text('Bắt đầu dẫn đường'));
    await tester.pumpAndSettle();

    expect(find.text('Live trip 10'), findsOneWidget);
    expect(openedExtra, _memberDetail);
  });

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

    expect(find.text('Chỉ xem (thành viên nhóm)'), findsOneWidget);
    expect(find.text('Chấp nhận lịch trình'), findsNothing);
    expect(find.text('Sắp xếp hoặc bỏ địa điểm'), findsNothing);
    expect(find.byTooltip('Tạo lại lịch trình'), findsNothing);
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
        find.text('Bạn không có quyền xem lịch trình này.'),
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

    expect(find.text('Không tìm thấy lịch trình này.'), findsOneWidget);
  });
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
  final sentStops = <List<ItineraryStop>>[];
  final updatedDetails = <ItineraryDetail>[];
  Failure? updateFailure;

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
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
  }) async {
    sentStops.add(stops);
    if (updateFailure != null) throw updateFailure!;
    return updatedDetails.isEmpty ? detail : updatedDetails.removeAt(0);
  }
}
