import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/app_initialization_status.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_location.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_location_service.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_location_use_case.dart';
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

  group('PoiMapPreview - Existing Behaviors', () {
    testWidgets('displays empty state when state.items is empty', (
      tester,
    ) async {
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
  });

  group('MAPBOX-P1-03: Missing Token & Headless Test Scenarios', () {
    testWidgets(
      'Test A: displays unavailable view when Mapbox token is missing (null)',
      (tester) async {
        serviceLocator.registerSingleton<AppConfig>(
          AppConfig(
            environment: Environment.development,
            apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
            mapboxAccessToken: null,
          ),
        );

        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
        );
        addTearDown(cubit.close);

        const state = PoiListState(
          status: PoiListStatus.success,
          items: [samplePoi1],
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

        expect(find.text('Bản đồ Mapbox chưa sẵn sàng'), findsOneWidget);
        expect(
          find.text(
            'Chưa cấu hình MAPBOX_ACCESS_TOKEN trong tệp cấu hình môi trường.',
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Đặt lại bộ lọc'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(OutlinedButton, 'Đặt lại bộ lọc'));
        await tester.pumpAndSettle();
      },
    );

    test('validates coordinate bounds and null island rejection', () {
      expect(PoiMapPreview.isValidCoordinate(null, 108.0), isFalse);
      expect(PoiMapPreview.isValidCoordinate(16.0, null), isFalse);
      expect(PoiMapPreview.isValidCoordinate(double.nan, 108.0), isFalse);
      expect(PoiMapPreview.isValidCoordinate(95.0, 108.0), isFalse);
      expect(PoiMapPreview.isValidCoordinate(-95.0, 108.0), isFalse);
      expect(PoiMapPreview.isValidCoordinate(16.0, 185.0), isFalse);
      expect(PoiMapPreview.isValidCoordinate(16.0, -185.0), isFalse);
      expect(PoiMapPreview.isValidCoordinate(0.00001, 0.00001), isFalse);
      expect(PoiMapPreview.isValidCoordinate(16.0611, 108.2238), isTrue);
    });

    testWidgets(
      'Test B: explicitly requested useMapbox: false renders headless fallback',
      (tester) async {
        serviceLocator.registerSingleton<AppConfig>(
          AppConfig(
            environment: Environment.development,
            apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
            mapboxAccessToken: 'pk.mock_valid_token',
          ),
        );

        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
        );
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
        expect(find.text('Bản đồ Mapbox chưa sẵn sàng'), findsNothing);
      },
    );
  });

  group('MAPBOX-P1-01: GPS Location State and Camera Handling', () {
    testWidgets(
      'successful location request updates camera using latest Cubit state, not stale widget state',
      (tester) async {
        final locationService = _TestLocationService(
          location: const PoiLocation(latitude: 16.0611, longitude: 108.2238),
        );
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
          getLocation: GetPoiLocationUseCase(locationService),
        );
        addTearDown(cubit.close);

        // Previous stale query has old coordinates (10.0, 105.0)
        const staleState = PoiListState(
          status: PoiListStatus.success,
          items: [samplePoi1],
          query: PoiQuery(originLatitude: 10.0, originLongitude: 105.0),
        );

        final fakeController = _FakePoiMapController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PoiMapPreview(
                state: staleState,
                cubit: cubit,
                controller: fakeController,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the location button
        await tester.tap(find.byTooltip('Vị trí của tôi'));
        await tester.pumpAndSettle();

        // Verify camera eased to the NEW coordinates from cubit.state, NOT stale widget.state!
        expect(fakeController.easeToLocationCallCount, 1);
        expect(fakeController.lastEasedLat, 16.0611);
        expect(fakeController.lastEasedLng, 108.2238);
      },
    );

    testWidgets(
      'permission denied does not move camera and preserves previous coordinates',
      (tester) async {
        final locationService = _TestLocationService(
          error: const LocationPermissionFailure('Quyền vị trí bị từ chối'),
        );
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
          getLocation: GetPoiLocationUseCase(locationService),
        );
        addTearDown(cubit.close);

        const state = PoiListState(
          status: PoiListStatus.success,
          items: [samplePoi1],
          query: PoiQuery(originLatitude: 10.0, originLongitude: 105.0),
        );

        final fakeController = _FakePoiMapController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PoiMapPreview(
                state: state,
                cubit: cubit,
                controller: fakeController,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Vị trí của tôi'));
        await tester.pumpAndSettle();

        expect(cubit.state.locationMessage, 'Quyền vị trí bị từ chối');
        expect(fakeController.easeToLocationCallCount, 0);
      },
    );

    testWidgets('location service unavailable does not move camera', (
      tester,
    ) async {
      final locationService = _TestLocationService(
        error: const ServerFailure('GPS chưa được bật'),
      );
      final cubit = PoiListCubit(
        getPois: GetPoisUseCase(_TestPoiRepository()),
        getLocation: GetPoiLocationUseCase(locationService),
      );
      addTearDown(cubit.close);

      const state = PoiListState(
        status: PoiListStatus.success,
        items: [samplePoi1],
        query: PoiQuery(),
      );

      final fakeController = _FakePoiMapController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PoiMapPreview(
              state: state,
              cubit: cubit,
              controller: fakeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Vị trí của tôi'));
      await tester.pumpAndSettle();

      expect(fakeController.easeToLocationCallCount, 0);
      expect(cubit.state.locationMessage, 'GPS chưa được bật');
    });

    testWidgets('invalid coordinates (out of range / NaN) do not move camera', (
      tester,
    ) async {
      final locationService = _TestLocationService(
        location: const PoiLocation(latitude: 95.0, longitude: 108.0),
      );
      final cubit = PoiListCubit(
        getPois: GetPoisUseCase(_TestPoiRepository()),
        getLocation: GetPoiLocationUseCase(locationService),
      );
      addTearDown(cubit.close);

      const state = PoiListState(
        status: PoiListStatus.success,
        items: [samplePoi1],
        query: PoiQuery(),
      );

      final fakeController = _FakePoiMapController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PoiMapPreview(
              state: state,
              cubit: cubit,
              controller: fakeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Vị trí của tôi'));
      await tester.pumpAndSettle();

      expect(fakeController.easeToLocationCallCount, 0);
    });

    testWidgets(
      'widget disposed before location request completes does not throw or move camera',
      (tester) async {
        final completer = Completer<PoiLocation>();
        final locationService = _TestLocationService(
          onLocation: () => completer.future,
        );
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
          getLocation: GetPoiLocationUseCase(locationService),
        );
        addTearDown(cubit.close);

        const state = PoiListState(
          status: PoiListStatus.success,
          items: [samplePoi1],
          query: PoiQuery(),
        );

        final fakeController = _FakePoiMapController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PoiMapPreview(
                state: state,
                cubit: cubit,
                controller: fakeController,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap location button -> request in flight
        await tester.tap(find.byTooltip('Vị trí của tôi'));
        await tester.pump();
        expect(cubit.state.isLocating, isTrue);

        // Unmount widget
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );

        // Complete the location request after unmount
        completer.complete(
          const PoiLocation(latitude: 16.0611, longitude: 108.2238),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(fakeController.easeToLocationCallCount, 0);
      },
    );

    testWidgets(
      'a newer user action superseding location request does not move camera to stale coordinates',
      (tester) async {
        final completer = Completer<PoiLocation>();
        final locationService = _TestLocationService(
          onLocation: () => completer.future,
        );
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
          getLocation: GetPoiLocationUseCase(locationService),
        );
        addTearDown(cubit.close);

        const state = PoiListState(
          status: PoiListStatus.success,
          items: [samplePoi1],
          query: PoiQuery(),
        );

        final fakeController = _FakePoiMapController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PoiMapPreview(
                state: state,
                cubit: cubit,
                controller: fakeController,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Vị trí của tôi'));
        await tester.pump();
        expect(cubit.state.isLocating, isTrue);

        // User changes category while location request is in flight (superseding it)
        unawaited(cubit.selectCategory(2));
        await tester.pump();

        // Location request completes
        completer.complete(
          const PoiLocation(latitude: 16.0611, longitude: 108.2238),
        );
        await tester.pumpAndSettle();

        // Category was changed; originLatitude is null in final state
        expect(cubit.state.query.originLatitude, isNull);
        expect(fakeController.easeToLocationCallCount, 0);
      },
    );
  });

  group('MAPBOX-P1-02: Isolated Initialization and Error Handling', () {
    testWidgets(
      'optional location settings failure does not prevent annotation managers from initializing',
      (tester) async {
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
        );
        addTearDown(cubit.close);

        const state = PoiListState(
          status: PoiListStatus.success,
          items: [samplePoi1],
          query: PoiQuery(),
        );

        final fakeController = _FakePoiMapController()
          ..shouldFailOptionalLocation = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PoiMapPreview(
                state: state,
                cubit: cubit,
                controller: fakeController,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(fakeController.initOptionalCalled, isTrue);
        expect(fakeController.initAnnotationManagersCalled, isTrue);
        expect(fakeController.syncCount, greaterThan(0));
        expect(
          find.text('Không thể tải điểm đánh dấu trên bản đồ.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'optional scale bar failure does not prevent annotation managers from initializing',
      (tester) async {
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
        );
        addTearDown(cubit.close);

        const state = PoiListState(
          status: PoiListStatus.success,
          items: [samplePoi1],
          query: PoiQuery(),
        );

        final fakeController = _FakePoiMapController()
          ..shouldFailOptionalScaleBar = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PoiMapPreview(
                state: state,
                cubit: cubit,
                controller: fakeController,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(fakeController.initOptionalCalled, isTrue);
        expect(fakeController.initAnnotationManagersCalled, isTrue);
        expect(fakeController.syncCount, greaterThan(0));
        expect(
          find.text('Không thể tải điểm đánh dấu trên bản đồ.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'essential annotation manager failure displays error banner with retry button',
      (tester) async {
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
        );
        addTearDown(cubit.close);

        const state = PoiListState(
          status: PoiListStatus.success,
          items: [samplePoi1],
          query: PoiQuery(),
        );

        final fakeController = _FakePoiMapController()
          ..shouldFailAnnotationManagers = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PoiMapPreview(
                state: state,
                cubit: cubit,
                controller: fakeController,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Không thể tải điểm đánh dấu trên bản đồ.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextButton, 'Thử lại'), findsOneWidget);
        expect(fakeController.syncCount, 0);
      },
    );

    testWidgets(
      'retry after recoverable essential failure re-initializes and draws markers without duplicate listeners',
      (tester) async {
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(_TestPoiRepository()),
        );
        addTearDown(cubit.close);

        const state = PoiListState(
          status: PoiListStatus.success,
          items: [samplePoi1],
          query: PoiQuery(),
        );

        final fakeController = _FakePoiMapController()
          ..shouldFailAnnotationManagers = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PoiMapPreview(
                state: state,
                cubit: cubit,
                controller: fakeController,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Không thể tải điểm đánh dấu trên bản đồ.'),
          findsOneWidget,
        );

        // Recover from failure and tap 'Thử lại'
        fakeController.shouldFailAnnotationManagers = false;
        await tester.tap(find.widgetWithText(TextButton, 'Thử lại'));
        await tester.pumpAndSettle();

        expect(
          find.text('Không thể tải điểm đánh dấu trên bản đồ.'),
          findsNothing,
        );
        expect(fakeController.annotationInitAttempts, 2);
        expect(fakeController.syncCount, greaterThan(0));

        // Test marker selection callback works properly
        fakeController.onPoiSelected!(samplePoi1.id);
        await tester.pumpAndSettle();
        expect(cubit.state.selectedPoiId, samplePoi1.id);
      },
    );

    testWidgets('disposing widget calls controller.dispose and cleans up', (
      tester,
    ) async {
      final cubit = PoiListCubit(getPois: GetPoisUseCase(_TestPoiRepository()));
      addTearDown(cubit.close);

      const state = PoiListState(
        status: PoiListStatus.success,
        items: [samplePoi1],
        query: PoiQuery(),
      );

      final fakeController = _FakePoiMapController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PoiMapPreview(
              state: state,
              cubit: cubit,
              controller: fakeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeController.isDisposed, isFalse);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );

      expect(fakeController.isDisposed, isTrue);
    });
  });
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

class _TestLocationService implements PoiLocationService {
  _TestLocationService({this.onLocation, this.location, this.error});

  final Future<PoiLocation> Function()? onLocation;
  final PoiLocation? location;
  final Object? error;

  @override
  Future<PoiLocation> requestCurrentLocation() async {
    if (onLocation != null) return onLocation!();
    if (error != null) throw error!;
    return location ??
        const PoiLocation(latitude: 16.0611, longitude: 108.2238);
  }
}

class _FakePoiMapController implements PoiMapController {
  bool initOptionalCalled = false;
  bool shouldFailOptionalLocation = false;
  bool shouldFailOptionalScaleBar = false;

  bool initAnnotationManagersCalled = false;
  bool shouldFailAnnotationManagers = false;
  int annotationInitAttempts = 0;
  void Function(int poiId)? onPoiSelected;

  int syncCount = 0;
  List<PoiSummary>? lastSyncedPois;
  int? lastSelectedId;
  bool? lastShowLabels;

  double? lastEasedLat;
  double? lastEasedLng;
  int easeToLocationCallCount = 0;

  bool isDisposed = false;

  @override
  Future<void> initOptionalSettings() async {
    initOptionalCalled = true;
    if (shouldFailOptionalLocation) {
      throw Exception('Optional location settings failed');
    }
    if (shouldFailOptionalScaleBar) {
      throw Exception('Optional scale bar settings failed');
    }
  }

  @override
  Future<bool> initAnnotationManagers({
    required void Function(int poiId) onPoiSelected,
  }) async {
    initAnnotationManagersCalled = true;
    annotationInitAttempts++;
    this.onPoiSelected = onPoiSelected;
    if (shouldFailAnnotationManagers) {
      return false;
    }
    return true;
  }

  @override
  Future<void> syncMarkers({
    required List<PoiSummary> pois,
    required int? selectedId,
    required bool showLabels,
    required bool fit,
    required bool easeToSelected,
  }) async {
    syncCount++;
    lastSyncedPois = pois;
    lastSelectedId = selectedId;
    lastShowLabels = showLabels;
  }

  @override
  Future<void> easeToLocation(double latitude, double longitude) async {
    easeToLocationCallCount++;
    lastEasedLat = latitude;
    lastEasedLng = longitude;
  }

  @override
  void dispose() {
    isDisposed = true;
  }
}
