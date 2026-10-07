import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_state.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';

class _StubPoiRepository implements PoiRepository {
  _StubPoiRepository(this._handler);

  final Future<PagedPoiResult> Function(PoiQuery query) _handler;

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) => _handler(query);

  @override
  Future<PoiDetail> getPoiDetail(int id) => throw UnimplementedError();
}

GetPoisUseCase _makeGetPois(
  Future<PagedPoiResult> Function(PoiQuery query) handler,
) {
  return GetPoisUseCase(_StubPoiRepository(handler));
}

void main() {
  setUp(() {
    DemoCommercialServiceStore.instance.reset();
  });

  final fakePoiSummaries = [
    const PoiSummary(
      id: 101,
      name: 'Grand Tourane Hotel Da Nang',
      categoryId: 10,
      categoryName: 'Hotel',
      latitude: 16.06,
      longitude: 108.24,
      address: '252 Vo Nguyen Giap, Son Tra, Da Nang',
      indoorOutdoor: 'Indoor',
      averageVisitDurationMinutes: 720,
      hasShelter: true,
      reviewCount: 150,
      averageRating: 4.6,
      isOpenNow: true,
    ),
    const PoiSummary(
      id: 102,
      name: 'Da Nang Coastal Motorbike Rental',
      categoryId: 11,
      categoryName: 'Vehicle Rental',
      latitude: 16.07,
      longitude: 108.23,
      address: '15 Ha Bong, Son Tra, Da Nang',
      indoorOutdoor: 'Outdoor',
      averageVisitDurationMinutes: 60,
      hasShelter: false,
      reviewCount: 88,
      averageRating: 4.8,
      isOpenNow: true,
    ),
    const PoiSummary(
      id: 103,
      name: 'Bep Cuon Da Nang Restaurant',
      categoryId: 12,
      categoryName: 'Restaurant',
      latitude: 16.05,
      longitude: 108.22,
      address: '54 Nguyen Van Thoai, Ngu Hanh Son, Da Nang',
      indoorOutdoor: 'Indoor',
      averageVisitDurationMinutes: 90,
      hasShelter: true,
      reviewCount: 210,
      averageRating: 4.7,
      isOpenNow: true,
    ),
    const PoiSummary(
      id: 104,
      name: 'Linh Ung Pagoda',
      categoryId: 1,
      categoryName: 'Attraction',
      latitude: 16.10,
      longitude: 108.27,
      address: 'Son Tra Peninsula, Da Nang',
      indoorOutdoor: 'Outdoor',
      averageVisitDurationMinutes: 120,
      hasShelter: true,
      reviewCount: 500,
      averageRating: 4.9,
      isOpenNow: true,
    ),
  ];

  group('CommercialServicesSearchCubit - Production Mode', () {
    test(
      'queries real GetPoisUseCase (REAL_BACKEND), does not expose ordinary POIs, and emits pendingIntegration for commercial catalog',
      () async {
        PoiQuery? capturedQuery;
        final mockGetPois = _makeGetPois((query) async {
          capturedQuery = query;
          return PagedPoiResult(
            items: fakePoiSummaries,
            totalCount: 4,
            page: 1,
            pageSize: 20,
            totalPages: 1,
          );
        });

        final cubit = CommercialServicesSearchCubit(
          getPois: mockGetPois,
          isDemoMode: false,
        );

        await cubit.loadInitial();

        expect(
          cubit.state.status,
          CommercialServicesSearchStatus.pendingIntegration,
        );
        expect(cubit.state.items, isEmpty);
        expect(capturedQuery, isNotNull);
        expect(capturedQuery!.page, 1);
      },
    );

    test(
      'passes search query to backend GetPoisUseCase (REAL_BACKEND) and preserves pendingIntegration status without exposing generic POIs',
      () async {
        PoiQuery? capturedQuery;
        final mockGetPois = _makeGetPois((query) async {
          capturedQuery = query;
          return PagedPoiResult(
            items: [fakePoiSummaries[0]],
            totalCount: 1,
            page: 1,
            pageSize: 20,
            totalPages: 1,
          );
        });

        final cubit = CommercialServicesSearchCubit(
          getPois: mockGetPois,
          isDemoMode: false,
        );

        await cubit.submitSearch('Tourane');

        expect(
          cubit.state.status,
          CommercialServicesSearchStatus.pendingIntegration,
        );
        expect(cubit.state.searchQuery, 'Tourane');
        expect(capturedQuery?.search, 'Tourane');
        expect(cubit.state.items, isEmpty);
      },
    );

    test(
      'Screen #71 invariant: never renders ordinary non-commercial POIs (Attraction, Museum) and preserves pagination without client-side page-local filtering',
      () async {
        final mixedSummaries = [
          fakePoiSummaries[0], // Hotel
          fakePoiSummaries[1], // Vehicle Rental
          fakePoiSummaries[2], // Restaurant
          fakePoiSummaries[3], // Attraction
        ];

        final mockGetPois = _makeGetPois((query) async {
          return PagedPoiResult(
            items: mixedSummaries,
            totalCount: 50,
            page: 1,
            pageSize: 20,
            totalPages: 3,
          );
        });

        final cubit = CommercialServicesSearchCubit(
          getPois: mockGetPois,
          isDemoMode: false,
        );

        await cubit.loadInitial();
        // Case B: Standalone commercial catalog is pending integration.
        // No generic POIs or attractions are exposed in items.
        expect(
          cubit.state.status,
          CommercialServicesSearchStatus.pendingIntegration,
        );
        expect(cubit.state.items, isEmpty);
        // Client-side page-local filtering is NEVER performed.
        expect(cubit.state.items.where((i) => i.category == null), isEmpty);
      },
    );

    test(
      'emits failure status with MSG127 on network or backend failure',
      () async {
        final mockGetPois = _makeGetPois((query) async {
          throw const ServerFailure('Backend error');
        });

        final cubit = CommercialServicesSearchCubit(
          getPois: mockGetPois,
          isDemoMode: false,
        );

        await cubit.loadInitial();

        expect(cubit.state.status, CommercialServicesSearchStatus.failure);
        expect(cubit.state.errorMessage, CommercialServiceMessages.msg127);
      },
    );
  });

  group('CommercialServicesSearchCubit - Demo Mode', () {
    test(
      'loads deterministic demo commercial pricing and availability',
      () async {
        final cubit = CommercialServicesSearchCubit(isDemoMode: true);

        await cubit.loadInitial();

        expect(cubit.state.status, CommercialServicesSearchStatus.success);
        expect(cubit.state.items, isNotEmpty);

        final hotel = cubit.state.items.firstWhere(
          (i) => i.category == CommercialServiceCategory.hotel,
        );
        expect(hotel.startingPriceVnd, 1450000);
        expect(hotel.availabilityStatusLabel, 'Available');
        expect(hotel.isCommercialDataBackedByServer, isTrue);

        final vehicle = cubit.state.items.firstWhere(
          (i) => i.category == CommercialServiceCategory.vehicleRental,
        );
        expect(vehicle.startingPriceVnd, 180000);

        final restaurant = cubit.state.items.firstWhere(
          (i) => i.category == CommercialServiceCategory.restaurant,
        );
        expect(restaurant.startingPriceVnd, 600000);
      },
    );

    test('filters demo items by category (BR-87)', () async {
      final cubit = CommercialServicesSearchCubit(isDemoMode: true);

      await cubit.selectCategory(CommercialServiceCategory.vehicleRental);

      expect(cubit.state.status, CommercialServicesSearchStatus.success);
      expect(
        cubit.state.items.every(
          (i) => i.category == CommercialServiceCategory.vehicleRental,
        ),
        isTrue,
      );
    });

    test('filters demo items by keyword search', () async {
      final cubit = CommercialServicesSearchCubit(isDemoMode: true);

      await cubit.submitSearch('Mobility');

      expect(cubit.state.status, CommercialServicesSearchStatus.success);
      expect(cubit.state.items.length, 1);
      expect(cubit.state.items.first.id, 902);
    });

    test('filters demo items by max price', () async {
      final cubit = CommercialServicesSearchCubit(isDemoMode: true);

      // Max price 500,000 VND should only match vehicle rental (180,000 VND)
      await cubit.updateMaxPrice(500000);

      expect(cubit.state.status, CommercialServicesSearchStatus.success);
      expect(
        cubit.state.items.every(
          (i) => i.startingPriceVnd != null && i.startingPriceVnd! <= 500000,
        ),
        isTrue,
      );
    });

    test('resets all filters to default catalog view', () async {
      final cubit = CommercialServicesSearchCubit(isDemoMode: true);

      await cubit.selectCategory(CommercialServiceCategory.vehicleRental);
      await cubit.submitSearch('Mobility');
      expect(cubit.state.items.length, 1);

      await cubit.resetFilters();

      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.selectedCategory, isNull);
      expect(cubit.state.items.length, greaterThan(1));
    });
  });
}
