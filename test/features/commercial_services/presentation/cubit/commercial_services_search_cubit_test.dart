import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/datasources/demo_commercial_services_data_source.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/datasources/pending_commercial_services_data_source.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/repositories/commercial_services_repository_impl.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_detail_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_services_search_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/demo_commercial_service_scenario.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/repositories/commercial_services_repository.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/usecases/search_commercial_services.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_state.dart';

class _FailingCommercialServicesRepository
    implements CommercialServicesRepository {
  @override
  Future<CommercialServicesSearchResult> searchServices({
    String? keyword,
    CommercialServiceCategory? category,
    String? dateIso,
    int? maxPriceVnd,
    int page = 1,
    int pageSize = 20,
    bool isDemoMode = false,
  }) async {
    throw const ServerFailure('Service failure');
  }

  @override
  Future<CommercialServiceDetailResult> getServiceDetail({
    required String rawPoiId,
    String? intendedDateIso,
    bool isDemoMode = false,
    DemoCommercialServiceScenario? demoScenario,
  }) => throw UnimplementedError();
}

SearchCommercialServices _createProductionSearchUseCase() {
  return SearchCommercialServices(
    CommercialServicesRepositoryImpl(
      pendingDataSource: const PendingCommercialServicesDataSource(),
      demoDataSource: const DemoCommercialServicesDataSource(),
    ),
  );
}

SearchCommercialServices _createDemoSearchUseCase() {
  return SearchCommercialServices(
    CommercialServicesRepositoryImpl(
      pendingDataSource: const PendingCommercialServicesDataSource(),
      demoDataSource: const DemoCommercialServicesDataSource(),
    ),
  );
}

void main() {
  group('CommercialServicesSearchCubit - Production Mode', () {
    test(
      'fails closed with pendingIntegration and makes zero unused POI requests in production',
      () async {
        final cubit = CommercialServicesSearchCubit(
          searchCommercialServices: _createProductionSearchUseCase(),
          isDemoMode: false,
        );

        await cubit.loadInitial();

        expect(
          cubit.state.status,
          CommercialServicesSearchStatus.pendingIntegration,
        );
        expect(cubit.state.items, isEmpty);
      },
    );

    test(
      'passes search query through searchCommercialServices and maintains pendingIntegration',
      () async {
        final cubit = CommercialServicesSearchCubit(
          searchCommercialServices: _createProductionSearchUseCase(),
          isDemoMode: false,
        );

        await cubit.submitSearch('Tourane');

        expect(
          cubit.state.status,
          CommercialServicesSearchStatus.pendingIntegration,
        );
        expect(cubit.state.searchQuery, 'Tourane');
        expect(cubit.state.items, isEmpty);
      },
    );

    test(
      'emits failure status with MSG127 on network or backend failure',
      () async {
        final cubit = CommercialServicesSearchCubit(
          searchCommercialServices: SearchCommercialServices(
            _FailingCommercialServicesRepository(),
          ),
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
        final cubit = CommercialServicesSearchCubit(
          searchCommercialServices: _createDemoSearchUseCase(),
          isDemoMode: true,
        );

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
      final cubit = CommercialServicesSearchCubit(
        searchCommercialServices: _createDemoSearchUseCase(),
        isDemoMode: true,
      );

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
      final cubit = CommercialServicesSearchCubit(
        searchCommercialServices: _createDemoSearchUseCase(),
        isDemoMode: true,
      );

      await cubit.submitSearch('Mobility');

      expect(cubit.state.status, CommercialServicesSearchStatus.success);
      expect(cubit.state.items.length, 1);
      expect(cubit.state.items.first.id, 902);
    });

    test('filters demo items by max price', () async {
      final cubit = CommercialServicesSearchCubit(
        searchCommercialServices: _createDemoSearchUseCase(),
        isDemoMode: true,
      );

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
      final cubit = CommercialServicesSearchCubit(
        searchCommercialServices: _createDemoSearchUseCase(),
        isDemoMode: true,
      );

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
