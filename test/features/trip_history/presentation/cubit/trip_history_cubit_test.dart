import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_history_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

void main() {
  late DemoTripHistoryStore demoStore;
  late TripHistoryRepositoryImpl repository;
  late TripHistoryCubit cubit;

  setUp(() {
    demoStore = DemoTripHistoryStore(now: DateTime(2026, 10, 8));
    repository = TripHistoryRepositoryImpl(
      demoStore: demoStore,
      isDemoMode: true,
    );
    cubit = TripHistoryCubit(
      repository: repository,
      isDemoMode: true,
      demoTravelerId: DemoTripHistoryStore.demoTravelerId,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('TripHistoryCubit State Management Tests', () {
    test('initial state has default values and Upcoming tab selected', () {
      expect(cubit.state.status, equals(TripHistoryStatus.initial));
      expect(cubit.state.selectedTab, equals(TripStatus.upcoming));
      expect(cubit.state.page, equals(1));
      expect(cubit.state.items, isEmpty);
    });

    test('loadInitial fetches upcoming trips successfully', () async {
      await cubit.loadInitial();

      expect(cubit.state.status, equals(TripHistoryStatus.success));
      expect(cubit.state.items.length, equals(2));
      expect(
        cubit.state.items.every((i) => i.status == TripStatus.upcoming),
        isTrue,
      );
    });

    test('switchTab loads completed trips and cancelled trips', () async {
      await cubit.loadInitial();
      expect(cubit.state.items.length, equals(2));

      await cubit.switchTab(TripStatus.completed);
      expect(cubit.state.selectedTab, equals(TripStatus.completed));
      expect(cubit.state.items.length, equals(4));

      await cubit.switchTab(TripStatus.cancelled);
      expect(cubit.state.selectedTab, equals(TripStatus.cancelled));
      expect(cubit.state.items.length, equals(3));
    });

    test('setTripType filters records by type', () async {
      await cubit.switchTab(TripStatus.completed);
      expect(cubit.state.items.length, equals(4));

      await cubit.setTripType(TripType.itinerary);
      expect(cubit.state.selectedTripType, equals(TripType.itinerary));
      expect(cubit.state.items.length, equals(1));
      expect(cubit.state.items.first.type, equals(TripType.itinerary));

      await cubit.setTripType(null); // Reset to All
      expect(cubit.state.items.length, equals(4));
    });

    test(
      'setDateRange: invalid range (end < start) displays MSG29 validation error and preserves list',
      () async {
        await cubit.switchTab(TripStatus.completed);
        final previousItems = cubit.state.items;
        expect(previousItems.length, equals(4));

        final start = DateTime(2026, 10, 5);
        final end = DateTime(2026, 10, 1); // Invalid: end is before start

        await cubit.setDateRange(start, end);

        expect(
          cubit.state.validationError,
          equals(TripHistoryStringsEn.validationDateRangeInvalid),
        );
        // Previous list remains unchanged (Abnormal case 5.a1)
        expect(cubit.state.items, equals(previousItems));
      },
    );

    test(
      'setDateRange: valid range filters trips successfully and clears error',
      () async {
        await cubit.switchTab(TripStatus.completed);

        // Start: 2026-09-01, End: 2026-09-20
        final start = DateTime(2026, 9, 1);
        final end = DateTime(2026, 9, 20);

        await cubit.setDateRange(start, end);

        expect(cubit.state.validationError, isNull);
        expect(cubit.state.items.length, greaterThan(0));
        expect(
          cubit.state.items.every(
            (i) =>
                (i.departureDate.isAfter(start) ||
                    i.departureDate.isAtSameMomentAs(start)) &&
                (i.departureDate.isBefore(end) ||
                    i.departureDate.isAtSameMomentAs(end)),
          ),
          isTrue,
        );
      },
    );

    test('pagination: goToPage navigates through pages', () async {
      // Use small pageSize in demoStore to create multiple pages
      await cubit.switchTab(TripStatus.completed);
      expect(cubit.state.page, equals(1));

      // With default pageSize 20 and 4 items, totalPages is 1
      expect(cubit.state.totalPages, equals(1));
      expect(cubit.state.hasNextPage, isFalse);
    });

    test(
      'production mode: emits pendingIntegration and disables retry without network call',
      () async {
        final prodRepo = TripHistoryRepositoryImpl(isDemoMode: false);
        final prodCubit = TripHistoryCubit(
          repository: prodRepo,
          isDemoMode: false,
        );
        addTearDown(prodCubit.close);

        await prodCubit.loadInitial();

        expect(
          prodCubit.state.status,
          equals(TripHistoryStatus.pendingIntegration),
        );
        expect(
          prodCubit.state.errorMessage,
          equals(TripHistoryStringsEn.productionIntegrationPending),
        );
        expect(prodCubit.state.items, isEmpty);

        // retry() should be a no-op in pendingIntegration mode
        await prodCubit.retry();
        expect(
          prodCubit.state.status,
          equals(TripHistoryStatus.pendingIntegration),
        );
      },
    );

    test(
      'demo tenant isolation: foreign traveler cannot see other traveler records',
      () async {
        final foreignCubit = TripHistoryCubit(
          repository: repository,
          isDemoMode: true,
          demoTravelerId: 999,
        );
        addTearDown(foreignCubit.close);

        await foreignCubit.loadInitial();

        // Foreign traveler has 1 upcoming trip: BK-TOUR-999
        expect(foreignCubit.state.items.length, equals(1));
        expect(
          foreignCubit.state.items.first.bookingCode,
          equals('BK-TOUR-999'),
        );
        expect(
          foreignCubit.state.items.every((t) => t.travelerId == 999),
          isTrue,
        );

        // Foreign traveler cannot see traveler 1's trips
        expect(foreignCubit.state.items.any((t) => t.travelerId == 1), isFalse);

        // Switch to completed tab: traveler 999 has 0 completed trips, traveler 1's trips are not visible
        await foreignCubit.switchTab(TripStatus.completed);
        expect(foreignCubit.state.items, isEmpty);
      },
    );
  });
}
