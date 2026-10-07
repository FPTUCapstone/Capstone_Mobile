import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_detail_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/pages/commercial_service_detail_page.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';

class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository({this.onGetPoiDetail});

  final Future<PoiDetail> Function(int id)? onGetPoiDetail;

  @override
  Future<PoiDetail> getPoiDetail(int id) async {
    if (onGetPoiDetail != null) {
      return onGetPoiDetail!(id);
    }
    throw const NotFoundFailure('POI not found.');
  }

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) {
    throw UnimplementedError();
  }
}

PoiDetail _samplePoi({
  int id = 10,
  String name = 'Han River Boutique Hotel',
  String status = 'Active',
  String categoryName = 'Hotel',
}) {
  return PoiDetail(
    id: id,
    name: name,
    description: 'Boutique riverside hotel in Da Nang.',
    status: status,
    categoryId: 1,
    categoryName: categoryName,
    latitude: 16.0678,
    longitude: 108.2208,
    address: '36 Bach Dang, Hai Chau, Da Nang',
    indoorOutdoor: 'Indoor',
    averageVisitDurationMinutes: 120,
    hasShelter: true,
    scenicScore: 4.5,
    photoRating: 4.6,
    averageRating: 4.7,
    reviewCount: 42,
    isOpenNow: true,
    openingHours: const [
      PoiOpeningHour(
        dayOfWeek: 1,
        openTime: '00:00',
        closeTime: '23:59',
        isClosed: false,
      ),
    ],
    photos: const [],
    tags: const [],
    createdAtUtc: DateTime.utc(2026, 1, 1),
    updatedAtUtc: DateTime.utc(2026, 1, 2),
  );
}

Widget _wrapWithCubit(
  CommercialServiceDetailCubit cubit, {
  double textScale = 1.0,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: BlocProvider.value(
      value: cubit,
      child: const CommercialServiceDetailPage(),
    ),
  );
}

void main() {
  setUp(() {
    DemoCommercialServiceStore.instance.reset();
  });

  group('CommercialServiceDetailPage - Production truthfulness & BR-87/BR-88', () {
    testWidgets(
      'Production commercial POI renders real POI details, Pending Server Integration notices, and disabled Book Service button',
      (tester) async {
        final repo = _FakePoiRepository(
          onGetPoiDetail: (id) async => _samplePoi(id: id),
        );
        final cubit = CommercialServiceDetailCubit(
          getPoiDetail: GetPoiDetailUseCase(repo),
          isDemoMode: false,
        );
        await cubit.load('10');

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        expect(find.text('Han River Boutique Hotel'), findsOneWidget);
        expect(find.text('36 Bach Dang, Hai Chau, Da Nang'), findsOneWidget);
        expect(
          find.byKey(const Key('commercial_service_production_partial_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_options_pending_notice')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_availability_pending_notice')),
          findsOneWidget,
        );

        final bookButton = tester.widget<FilledButton>(
          find.byKey(const Key('commercial_service_book_button')),
        );
        expect(bookButton.onPressed, isNull);
      },
    );

    testWidgets(
      'Production ordinary non-commercial POI (Museum) hides Book Service button completely (BR-87)',
      (tester) async {
        final repo = _FakePoiRepository(
          onGetPoiDetail: (id) async => _samplePoi(
            id: id,
            name: 'Cham Sculpture Museum',
            categoryName: 'Museum',
          ),
        );
        final cubit = CommercialServiceDetailCubit(
          getPoiDetail: GetPoiDetailUseCase(repo),
          isDemoMode: false,
        );
        await cubit.load('15');

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        expect(find.text('Cham Sculpture Museum'), findsOneWidget);
        expect(
          find.byKey(const Key('commercial_service_book_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Inactive or missing POI renders MSG34 and no commercial details (BR-34, BR-55)',
      (tester) async {
        final repo = _FakePoiRepository(
          onGetPoiDetail: (id) async => _samplePoi(id: id, status: 'Inactive'),
        );
        final cubit = CommercialServiceDetailCubit(
          getPoiDetail: GetPoiDetailUseCase(repo),
          isDemoMode: false,
        );
        await cubit.load('10');

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_service_msg34_view')),
          findsOneWidget,
        );
        expect(find.text(CommercialServiceMessages.msg34), findsOneWidget);
      },
    );
  });

  group('CommercialServiceDetailPage - Demo scenarios & Map preview', () {
    testWidgets(
      'renders Hotel, Vehicle Rental, and Restaurant category-specific details and opens View on Map sheet',
      (tester) async {
        final cubit = CommercialServiceDetailCubit(isDemoMode: true);
        await cubit.load('901');

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        // Hotel scenario
        expect(find.text('Room Types (Hotel)'), findsOneWidget);
        expect(find.text('Deluxe Ocean View Room'), findsOneWidget);
        final bookBtn = tester.widget<FilledButton>(
          find.byKey(const Key('commercial_service_book_button')),
        );
        expect(bookBtn.onPressed, isNotNull);

        // Switch to Vehicle Rental
        cubit.selectDemoScenario(
          DemoCommercialServiceScenario.availableVehicleRental,
        );
        await tester.pumpAndSettle();
        expect(find.text('Vehicle Types (Vehicle Rental)'), findsOneWidget);

        // Switch to Restaurant
        cubit.selectDemoScenario(
          DemoCommercialServiceScenario.availableRestaurant,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Menu Highlights & Table Capacity (Restaurant)'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('restaurant_table_capacity_text')),
          findsOneWidget,
        );

        // Open View on Map sheet
        final mapBtnFinder = find.byKey(
          const Key('commercial_service_view_map_button'),
        );
        await tester.ensureVisible(mapBtnFinder);
        await tester.tap(mapBtnFinder);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_map_sheet_close_button')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('commercial_map_sheet_close_button')),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'renders MSG126 when availability is unavailable, MSG75 when closed for booking, and MSG127 on system failure',
      (tester) async {
        final cubit = CommercialServiceDetailCubit(isDemoMode: true);
        await cubit.load('906');

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        // MSG126
        expect(find.text(CommercialServiceMessages.msg126), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('commercial_service_book_button')),
              )
              .onPressed,
          isNull,
        );

        // MSG75
        cubit.selectDemoScenario(
          DemoCommercialServiceScenario.closedForBooking,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('commercial_service_msg75_banner')),
          findsOneWidget,
        );
        expect(
          find.text(CommercialServiceMessages.msg75),
          findsAtLeastNWidgets(1),
        );

        // MSG127
        cubit.selectDemoScenario(DemoCommercialServiceScenario.systemFailure);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('commercial_service_msg127_view')),
          findsOneWidget,
        );
        expect(find.text(CommercialServiceMessages.msg127), findsOneWidget);
        expect(
          find.byKey(const Key('commercial_service_retry_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders cleanly across 360x640, 390x844, 412x915 viewports and 200% text scale without RenderFlex overflow',
      (tester) async {
        final cubit = CommercialServiceDetailCubit(isDemoMode: true);
        await cubit.load('903');

        for (final size in const [
          Size(360, 640),
          Size(390, 844),
          Size(412, 915),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(_wrapWithCubit(cubit));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await tester.binding.setSurfaceSize(const Size(360, 640));
        await tester.pumpWidget(_wrapWithCubit(cubit, textScale: 2.0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
