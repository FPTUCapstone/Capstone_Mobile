import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/paged_tour_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_category.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_category_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_search_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/load_tour_categories_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/pages/tour_search_page.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/widgets/dev_tour_search_controls.dart';

void main() {
  test(
    'failed overlapping replacement restores data-owned query before pagination',
    () async {
      final repository = _Repository();
      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
        devSearchEnabled: true,
      );
      addTearDown(cubit.close);
      const item = TourSummary(
        tourId: 'A1',
        title: 'A tour',
        destinations: [],
        operatorName: 'Op',
        durationDays: 1,
        basePrice: 1,
        currency: 'VND',
        representativeScheduleId: null,
        departureAtUtc: null,
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 1,
      );
      repository.pending = Future.value(
        const PagedTourResult(
          page: 1,
          pageSize: 1,
          totalCount: 3,
          totalPages: 3,
          items: [item],
        ),
      );
      await cubit.applyV2Query(
        const TourSearchQuery(keyword: 'A', pageSize: 1),
      );
      repository.pending = Future.value(
        const PagedTourResult(
          page: 2,
          pageSize: 1,
          totalCount: 3,
          totalPages: 3,
          items: [item],
        ),
      );
      await cubit.loadNextPage();
      final pendingB = Completer<PagedTourResult>();
      repository.pending = pendingB.future;
      final requestB = cubit.applyV2Query(const TourSearchQuery(keyword: 'B'));
      repository.pending = Future.error(const ServerFailure());
      await cubit.applyV2Query(const TourSearchQuery(keyword: 'C'));
      expect(cubit.state.query.keyword, 'A');
      expect(cubit.state.query.page, 2);
      repository.pending = Future.value(
        const PagedTourResult(
          page: 3,
          pageSize: 1,
          totalCount: 3,
          totalPages: 3,
          items: [item],
        ),
      );
      await cubit.loadNextPage();
      expect(repository.queries.last.keyword, 'A');
      expect(repository.queries.last.page, 3);
      pendingB.complete(
        const PagedTourResult(
          page: 1,
          pageSize: 20,
          totalCount: 0,
          totalPages: 0,
          items: [],
        ),
      );
      await requestB;
      expect(cubit.state.query.keyword, 'A');
    },
  );
  testWidgets(
    'V2 filter sheet uses server categories and preserves query/date range',
    (tester) async {
      final repository = _Repository();
      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
        devSearchEnabled: true,
        loadCategories: LoadTourCategoriesUseCase(_Categories()),
      );
      addTearDown(cubit.close);
      await cubit.applyV2Query(
        TourSearchQuery(
          keyword: 'biển',
          mode: 'hybrid',
          sort: 'rating',
          departureDate: DateTime(2027, 1, 1),
          endDate: DateTime(2027, 1, 5),
        ),
      );
      await cubit.loadCategories();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DevTourSearchFilterSheet(cubit: cubit)),
        ),
      );
      for (final entry in {
        'Destination': 'Đà Nẵng',
        'Minimum price': '100',
        'Maximum price': '500',
        'Duration (days)': '3',
        'Minimum rating (1–5)': '4.5',
      }.entries) {
        await tester.ensureVisible(find.widgetWithText(TextField, entry.key));
        await tester.enterText(
          find.widgetWithText(TextField, entry.key),
          entry.value,
        );
      }
      await tester.ensureVisible(find.text('Category'));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tên từ server').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      final query = repository.queries.last;
      expect(query.keyword, 'biển');
      expect(query.mode, 'hybrid');
      expect(query.category, 'server-only-code');
      expect(query.minimumRating, 4.5);
      expect(query.departureDate, DateTime(2027, 1, 1));
      expect(query.endDate, DateTime(2027, 1, 5));
      expect(query.minPrice, 100);
      expect(query.maxPrice, 500);
      expect(query.durationDays, 3);
    },
  );
  testWidgets(
    'dev keyword and mode submit through cubit without legacy UI changes',
    (tester) async {
      final repository = _Repository();
      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
        devSearchEnabled: true,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cubit, child: const TourSearchPage()),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('dev-search-keyword')),
        'biển yên tĩnh',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repository.queries.last.keyword, 'biển yên tĩnh');
      expect(find.text('Semantic'), findsOneWidget);
      await tester.tap(find.text('Semantic'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.mode, 'semantic');
      await cubit.resetFilters();
      await tester.pumpAndSettle();
      final input = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('dev-search-keyword')),
          matching: find.byType(EditableText),
        ),
      );
      expect(input.controller.text, 'biển yên tĩnh');
    },
  );
  test('newer search supersedes stale response', () async {
    final repository = _Repository();
    final cubit = TourSearchCubit(
      searchTours: SearchToursUseCase(repository),
      devSearchEnabled: true,
    );
    addTearDown(cubit.close);
    final first = Completer<PagedTourResult>();
    repository.pending = first.future;
    final older = cubit.applyV2Query(const TourSearchQuery(keyword: 'old'));
    repository.pending = null;
    await cubit.applyV2Query(const TourSearchQuery(keyword: 'new'));
    first.complete(
      const PagedTourResult(
        page: 1,
        pageSize: 20,
        totalCount: 99,
        totalPages: 5,
        items: [],
      ),
    );
    await older;
    expect(cubit.state.query.keyword, 'new');
    expect(cubit.state.totalCount, 0);
  });

  testWidgets('shows explicit one-based pagination for V2 results', (
    tester,
  ) async {
    final repository = _Repository();
    repository.pending = Future.value(
      const PagedTourResult(
        page: 1,
        pageSize: 20,
        totalCount: 41,
        totalPages: 3,
        items: [
          TourSummary(
            tourId: 'P1',
            title: 'Paged tour',
            destinations: [],
            operatorName: 'Operator',
            durationDays: 2,
            basePrice: 1,
            currency: 'VND',
            representativeScheduleId: null,
            departureAtUtc: null,
            availabilityStatus: AvailabilityStatus.available,
            remainingSlots: 1,
          ),
        ],
      ),
    );
    final cubit = TourSearchCubit(
      searchTours: SearchToursUseCase(repository),
      devSearchEnabled: true,
    );
    addTearDown(cubit.close);
    await cubit.applyV2Query(const TourSearchQuery(keyword: 'sea'));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const TourSearchPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(find.byTooltip('Previous page'), findsOneWidget);
    expect(find.byTooltip('Next page'), findsOneWidget);
  });
}

class _Categories implements TourCategoryRepository {
  @override
  Future<List<TourCategory>> loadCategories() async => [
    const TourCategory(code: 'server-only-code', name: 'Tên từ server'),
  ];
}

class _Repository implements TourSearchRepository {
  final queries = <TourSearchQuery>[];
  Future<PagedTourResult>? pending;
  @override
  Future<PagedTourResult> searchTours(TourSearchQuery query) async {
    queries.add(query);
    return pending ??
        Future.value(
          const PagedTourResult(
            page: 1,
            pageSize: 20,
            totalCount: 0,
            totalPages: 0,
            items: [],
          ),
        );
  }
}
