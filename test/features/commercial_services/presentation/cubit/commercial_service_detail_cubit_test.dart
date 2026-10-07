import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_detail_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_detail_state.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';
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

void main() {
  setUp(() {
    DemoCommercialServiceStore.instance.reset();
  });

  group('CommercialServiceCategory (BR-87)', () {
    test('recognizes only Hotel, Vehicle Rental, and Restaurant', () {
      expect(
        CommercialServiceCategory.tryFromCategoryName('Hotel'),
        CommercialServiceCategory.hotel,
      );
      expect(
        CommercialServiceCategory.tryFromCategoryName('Vehicle Rental'),
        CommercialServiceCategory.vehicleRental,
      );
      expect(
        CommercialServiceCategory.tryFromCategoryName('Restaurant'),
        CommercialServiceCategory.restaurant,
      );

      expect(CommercialServiceCategory.tryFromCategoryName('Museum'), isNull);
      expect(
        CommercialServiceCategory.tryFromCategoryName('Attraction'),
        isNull,
      );
      expect(CommercialServiceCategory.tryFromCategoryName('Beach'), isNull);
      expect(CommercialServiceCategory.tryFromCategoryName('Vehicle'), isNull);
      expect(CommercialServiceCategory.isCommercialCategory('Hotel'), isTrue);
      expect(CommercialServiceCategory.isCommercialCategory('Museum'), isFalse);
    });
  });

  group('CommercialServiceDetailCubit - Production mode', () {
    test(
      'loads active commercial POI from real GetPoiDetailUseCase without fabricating options or availability (BR-88)',
      () async {
        final repo = _FakePoiRepository(
          onGetPoiDetail: (id) async => _samplePoi(id: id),
        );
        final cubit = CommercialServiceDetailCubit(
          getPoiDetail: GetPoiDetailUseCase(repo),
          isDemoMode: false,
        );

        await cubit.load('10');

        expect(cubit.state.status, CommercialServiceDetailStatus.loaded);
        final composite = cubit.state.composite!;
        expect(composite.poi.name, 'Han River Boutique Hotel');
        expect(composite.commercialCategory, CommercialServiceCategory.hotel);
        expect(composite.isCommercialDataBackedByServer, isFalse);
        expect(composite.options, isEmpty);
        expect(composite.availability, isNull);
        expect(composite.canBookService, isFalse);
      },
    );

    test(
      'ordinary non-commercial POI category sets isCommercialPoi false and never enables booking (BR-87)',
      () async {
        final repo = _FakePoiRepository(
          onGetPoiDetail: (id) async =>
              _samplePoi(id: id, categoryName: 'Museum'),
        );
        final cubit = CommercialServiceDetailCubit(
          getPoiDetail: GetPoiDetailUseCase(repo),
          isDemoMode: false,
        );

        await cubit.load('11');

        expect(cubit.state.status, CommercialServiceDetailStatus.loaded);
        expect(cubit.state.composite!.isCommercialPoi, isFalse);
        expect(cubit.state.composite!.canBookService, isFalse);
      },
    );

    test(
      'inactive POI emits inactiveOrNotFound with MSG34 (BR-34, BR-55)',
      () async {
        final repo = _FakePoiRepository(
          onGetPoiDetail: (id) async => _samplePoi(id: id, status: 'Inactive'),
        );
        final cubit = CommercialServiceDetailCubit(
          getPoiDetail: GetPoiDetailUseCase(repo),
          isDemoMode: false,
        );

        await cubit.load('12');

        expect(
          cubit.state.status,
          CommercialServiceDetailStatus.inactiveOrNotFound,
        );
        expect(cubit.state.errorMessage, CommercialServiceMessages.msg34);
      },
    );

    test(
      'missing POI (NotFoundFailure) emits inactiveOrNotFound with MSG34',
      () async {
        final repo = _FakePoiRepository(
          onGetPoiDetail: (_) async =>
              throw const NotFoundFailure('POI not found.'),
        );
        final cubit = CommercialServiceDetailCubit(
          getPoiDetail: GetPoiDetailUseCase(repo),
          isDemoMode: false,
        );

        await cubit.load('404');

        expect(
          cubit.state.status,
          CommercialServiceDetailStatus.inactiveOrNotFound,
        );
        expect(cubit.state.errorMessage, CommercialServiceMessages.msg34);
      },
    );

    test('network failure emits failure with MSG127', () async {
      final repo = _FakePoiRepository(
        onGetPoiDetail: (_) async =>
            throw const NetworkFailure('Connection error.'),
      );
      final cubit = CommercialServiceDetailCubit(
        getPoiDetail: GetPoiDetailUseCase(repo),
        isDemoMode: false,
      );

      await cubit.load('10');

      expect(cubit.state.status, CommercialServiceDetailStatus.failure);
      expect(cubit.state.errorMessage, CommercialServiceMessages.msg127);
    });
  });

  group('CommercialServiceDetailCubit - Demo mode', () {
    test(
      'loads Hotel, Vehicle Rental, and Restaurant scenarios with options and verified availability',
      () async {
        final cubit = CommercialServiceDetailCubit(isDemoMode: true);

        await cubit.load('901');
        expect(cubit.state.status, CommercialServiceDetailStatus.loaded);
        expect(
          cubit.state.composite!.commercialCategory,
          CommercialServiceCategory.hotel,
        );
        expect(cubit.state.composite!.options, isNotEmpty);
        expect(cubit.state.composite!.canBookService, isTrue);

        cubit.selectDemoScenario(
          DemoCommercialServiceScenario.availableVehicleRental,
        );
        expect(
          cubit.state.composite!.commercialCategory,
          CommercialServiceCategory.vehicleRental,
        );
        expect(cubit.state.composite!.options, isNotEmpty);
        expect(cubit.state.composite!.canBookService, isTrue);

        cubit.selectDemoScenario(
          DemoCommercialServiceScenario.availableRestaurant,
        );
        expect(
          cubit.state.composite!.commercialCategory,
          CommercialServiceCategory.restaurant,
        );
        expect(cubit.state.composite!.restaurantInfo, isNotNull);
        expect(
          cubit.state.composite!.restaurantInfo!.menuHighlights,
          isNotEmpty,
        );
        expect(cubit.state.composite!.canBookService, isTrue);
      },
    );

    test(
      'handles MSG34, non-commercial POI, missing availability without MSG126, MSG75, and MSG127 demo scenarios',
      () {
        final cubit = CommercialServiceDetailCubit(isDemoMode: true);

        cubit.selectDemoScenario(DemoCommercialServiceScenario.inactivePoi);
        expect(
          cubit.state.status,
          CommercialServiceDetailStatus.inactiveOrNotFound,
        );
        expect(cubit.state.errorMessage, CommercialServiceMessages.msg34);

        cubit.selectDemoScenario(
          DemoCommercialServiceScenario.unsupportedCategory,
        );
        expect(cubit.state.status, CommercialServiceDetailStatus.loaded);
        expect(cubit.state.composite!.isCommercialPoi, isFalse);
        expect(cubit.state.composite!.canBookService, isFalse);

        cubit.selectDemoScenario(
          DemoCommercialServiceScenario.availabilityUnavailable,
        );
        expect(cubit.state.status, CommercialServiceDetailStatus.loaded);
        expect(cubit.state.composite!.availability, isNull);
        expect(cubit.state.composite!.canBookService, isFalse);

        cubit.selectDemoScenario(
          DemoCommercialServiceScenario.closedForBooking,
        );
        expect(cubit.state.status, CommercialServiceDetailStatus.loaded);
        expect(cubit.state.noticeMessage, CommercialServiceMessages.msg75);
        expect(cubit.state.composite!.canBookService, isFalse);

        cubit.selectDemoScenario(DemoCommercialServiceScenario.systemFailure);
        expect(cubit.state.status, CommercialServiceDetailStatus.failure);
        expect(cubit.state.errorMessage, CommercialServiceMessages.msg127);
      },
    );
  });
}
