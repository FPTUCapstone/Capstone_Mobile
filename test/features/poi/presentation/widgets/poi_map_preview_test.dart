import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/app_initialization_status.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_map_preview.dart';

void main() {
  const samplePoi1 = PoiSummary(
    id: 1,
    name: 'Cầu Rồng Đà Nẵng',
    categoryId: 1,
    latitude: 16.0611,
    longitude: 108.2238,
    categoryName: 'Danh lam & Di sản',
    indoorOutdoor: 'Outdoor',
    averageVisitDurationMinutes: 60,
    hasShelter: false,
    averageRating: 4.8,
    reviewCount: 2800,
    isOpenNow: true,
    distanceKm: 1.2,
  );

  const samplePoi2 = PoiSummary(
    id: 2,
    name: 'Bãi biển Mỹ Khê',
    categoryId: 2,
    latitude: 16.0594,
    longitude: 108.2435,
    categoryName: 'Bãi biển',
    indoorOutdoor: 'Outdoor',
    averageVisitDurationMinutes: 120,
    hasShelter: false,
    averageRating: 4.7,
    reviewCount: 2200,
    isOpenNow: true,
    distanceKm: 3.2,
  );

  setUp(() {
    if (serviceLocator.isRegistered<AppConfig>()) {
      serviceLocator.unregister<AppConfig>();
    }
    if (serviceLocator.isRegistered<AppInitializationStatus>()) {
      serviceLocator.unregister<AppInitializationStatus>();
    }
  });

  tearDown(() {
    if (serviceLocator.isRegistered<AppConfig>()) {
      serviceLocator.unregister<AppConfig>();
    }
    if (serviceLocator.isRegistered<AppInitializationStatus>()) {
      serviceLocator.unregister<AppInitializationStatus>();
    }
  });

  testWidgets('displays empty state when state.items is empty', (tester) async {
    final cubit = PoiListCubit(getPois: GetPoisUseCase(_TestPoiRepository()));
    addTearDown(cubit.close);

    const state = PoiListState(
      status: PoiListStatus.success,
      items: [],
      query: PoiQuery(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoiMapPreview(state: state, cubit: cubit),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Không có địa điểm để hiển thị trên bản đồ.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Đặt lại'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Đặt lại'));
    await tester.pumpAndSettle();
  });

  testWidgets('displays headless fallback with selected POI preview card', (
    tester,
  ) async {
    final cubit = PoiListCubit(getPois: GetPoisUseCase(_TestPoiRepository()));
    addTearDown(cubit.close);

    const state = PoiListState(
      status: PoiListStatus.success,
      items: [samplePoi1, samplePoi2],
      selectedPoiId: 1,
      query: PoiQuery(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoiMapPreview(state: state, cubit: cubit),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bản đồ minh họa vị trí'), findsOneWidget);
    expect(find.text('Cầu Rồng Đà Nẵng'), findsOneWidget);
    expect(find.text('Xem chi tiết'), findsOneWidget);
    expect(find.text('ĐANG CHỌN'), findsOneWidget);
  });

  testWidgets('falls back to first POI in headless mode when none selected', (
    tester,
  ) async {
    final cubit = PoiListCubit(getPois: GetPoisUseCase(_TestPoiRepository()));
    addTearDown(cubit.close);

    const state = PoiListState(
      status: PoiListStatus.success,
      items: [samplePoi2],
      selectedPoiId: null,
      query: PoiQuery(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoiMapPreview(state: state, cubit: cubit),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bản đồ minh họa vị trí'), findsOneWidget);
    expect(find.text('Bãi biển Mỹ Khê'), findsOneWidget);
    expect(find.text('Xem chi tiết'), findsOneWidget);
  });

  testWidgets(
    'displays unavailable view when token is missing and not headless',
    (tester) async {
      serviceLocator.registerSingleton<AppConfig>(
        AppConfig(
          environment: Environment.development,
          apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
          mapboxAccessToken: null,
        ),
      );

      final cubit = PoiListCubit(getPois: GetPoisUseCase(_TestPoiRepository()));
      addTearDown(cubit.close);

      const state = PoiListState(
        status: PoiListStatus.success,
        items: [samplePoi1],
        query: PoiQuery(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PoiMapPreview(state: state, cubit: cubit, useMapbox: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bản đồ minh họa vị trí'), findsOneWidget);
    },
  );
}

class _TestPoiRepository implements PoiRepository {
  @override
  Future<PagedPoiResult> getPois(PoiQuery query) async {
    return const PagedPoiResult(
      page: 1,
      pageSize: 20,
      totalCount: 0,
      totalPages: 0,
      items: [],
    );
  }

  @override
  Future<PoiDetail> getPoiDetail(int id) => throw UnimplementedError();
}
