import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/paged_tour_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_search_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/pages/tour_search_page.dart';

void main() {
  group('TourSearchPage', () {
    testWidgets('renders tours and header in success state', (tester) async {
      final repository = _FakeTourRepository(
        result: const PagedTourResult(
          page: 1,
          pageSize: 20,
          totalCount: 1,
          totalPages: 1,
          items: [
            TourSummary(
              tourId: '1',
              title: 'Tour Ngũ Hành Sơn 1N',
              destinations: ['Đà Nẵng'],
              operatorName: 'Danang Discovery',
              durationDays: 1,
              basePrice: 500000,
              currency: 'VND',
              representativeScheduleId: '1',
              departureAtUtc: null,
              availabilityStatus: AvailabilityStatus.available,
              remainingSlots: 8,
            ),
          ],
        ),
      );

      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const TourSearchPage(isTraveler: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TripMate'), findsOneWidget);
      expect(find.text('Tìm kiếm Tour'), findsOneWidget);
      expect(find.text('TOURS'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Lọc tour'), findsOneWidget);
      expect(find.text('Tìm thấy 1 tour'), findsOneWidget);
      expect(find.text('Tour Ngũ Hành Sơn 1N'), findsOneWidget);
    });

    testWidgets('hides login button when user is a traveler', (tester) async {
      final repository = _FakeTourRepository(
        result: const PagedTourResult(
          page: 1,
          pageSize: 20,
          totalCount: 0,
          totalPages: 0,
          items: [],
        ),
      );

      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const TourSearchPage(isTraveler: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập'), findsNothing);
    });

    testWidgets('renders empty state when no tours match', (tester) async {
      final repository = _FakeTourRepository(
        result: const PagedTourResult(
          page: 1,
          pageSize: 20,
          totalCount: 0,
          totalPages: 0,
          items: [],
        ),
      );

      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cubit, child: const TourSearchPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy tour phù hợp'), findsOneWidget);
      expect(find.text('Đặt lại bộ lọc'), findsOneWidget);
    });

    testWidgets('renders error state on failure', (tester) async {
      final repository = _FakeTourRepository(
        error: const NetworkFailure('Lỗi kết nối mạng.'),
      );

      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cubit, child: const TourSearchPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa thể tải danh sách tour'), findsOneWidget);
      expect(find.text('Lỗi kết nối mạng.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('opens filter sheet on filter button tap', (tester) async {
      final repository = _FakeTourRepository(
        result: const PagedTourResult(
          page: 1,
          pageSize: 20,
          totalCount: 0,
          totalPages: 0,
          items: [],
        ),
      );

      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cubit, child: const TourSearchPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Lọc tour'));
      await tester.pumpAndSettle();

      expect(find.text('Bộ lọc tìm kiếm'), findsOneWidget);
      expect(find.text('Điểm đến'), findsOneWidget);
      expect(find.text('Ngày khởi hành'), findsOneWidget);
      expect(find.text('Khoảng giá (VNĐ)'), findsOneWidget);
    });
  });
}

final class _FakeTourRepository implements TourSearchRepository {
  _FakeTourRepository({this.result, this.error});

  final PagedTourResult? result;
  final Failure? error;

  @override
  Future<PagedTourResult> searchTours(TourSearchQuery query) async {
    if (error != null) throw error!;
    return result!;
  }
}
