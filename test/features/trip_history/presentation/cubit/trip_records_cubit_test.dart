import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/trip_records_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

BookingTripRecord _booking(int id, {TripStatus tab = TripStatus.upcoming}) =>
    BookingTripRecord(
      id: id,
      tab: tab,
      title: 'Tour $id',
      departureAtUtc: DateTime.utc(2026, 10, 1, 2),
      status: 'Confirmed',
      actions: const TripRecordActions(
        canReview: false,
        canViewETicket: false,
        ticketId: null,
        canViewRefund: false,
      ),
      bookingCode: 'TM-$id',
      participantCount: 2,
      totalAmount: 1000000,
      reviewableRecord: ReviewableRecordRef(
        kind: ReviewableRecordKind.commerceBooking,
        id: id,
      ),
      review: const TripRecordReview(exists: false),
    );

TripRecordPage _page(
  List<TripRecord> items, {
  int page = 1,
  int totalCount = 0,
  TripRecordSummary? summary,
}) => TripRecordPage(
  items: items,
  page: page,
  pageSize: 20,
  totalCount: totalCount == 0 ? items.length : totalCount,
  summary: summary,
);

final class _Repository implements TripRecordsRepository {
  final List<TripRecordsQuery> queries = [];
  Future<TripRecordPage> Function(TripRecordsQuery query) onPage =
      (query) async => _page([_booking(1, tab: query.tab)]);

  @override
  Future<TripRecordPage> getPage(TripRecordsQuery query) {
    queries.add(query);
    return onPage(query);
  }

  @override
  Future<TripRecordDetail> getDetail(TripRecordKind kind, int id) =>
      throw UnimplementedError();
}

({TripRecordsCubit cubit, _Repository repository}) _build() {
  final repository = _Repository();
  return (
    cubit: TripRecordsCubit(useCase: TripRecordsUseCase(repository)),
    repository: repository,
  );
}

void main() {
  test('starts on the Upcoming tab with nothing loaded', () {
    final built = _build();
    addTearDown(built.cubit.close);

    expect(built.cubit.state.status, TripRecordsStatus.initial);
    expect(built.cubit.state.selectedTab, TripStatus.upcoming);
    expect(built.cubit.state.tripType, TripRecordTypeFilter.all);
    expect(built.cubit.state.page, 1);
    expect(built.cubit.state.items, isEmpty);
    expect(built.cubit.state.startDate, isNull);
  });

  group('loadInitial', () {
    test(
      'emits loading then success with the page the use case returned',
      () async {
        final built = _build();
        addTearDown(built.cubit.close);
        built.repository.onPage = (_) async => _page(
          [_booking(1), _booking(2)],
          totalCount: 45,
          summary: const TripRecordSummary(
            totalCompletedTrips: 45,
            totalVisitedPois: 9,
          ),
        );
        final states = <TripRecordsStatus>[];
        final subscription = built.cubit.stream.listen(
          (s) => states.add(s.status),
        );

        await built.cubit.loadInitial();
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states, [TripRecordsStatus.loading, TripRecordsStatus.success]);
        expect(built.cubit.state.items.map((i) => i.id), [1, 2]);
        expect(built.cubit.state.totalCount, 45);
        expect(built.cubit.state.totalPages, 3);
        expect(built.cubit.state.summary?.totalVisitedPois, 9);
        expect(
          built.repository.queries.single,
          const TripRecordsQuery(tab: TripStatus.upcoming),
        );
      },
    );

    test('an empty page is a success with no items', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      built.repository.onPage = (_) async => _page([]);

      await built.cubit.loadInitial();

      expect(built.cubit.state.status, TripRecordsStatus.success);
      expect(built.cubit.state.isEmpty, isTrue);
    });
  });

  group('filters', () {
    test('switchTab asks for that tab on page 1', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      await built.cubit.loadInitial();
      await built.cubit.goToPage(1);

      await built.cubit.switchTab(TripStatus.cancelled);

      expect(built.repository.queries.last.tab, TripStatus.cancelled);
      expect(built.repository.queries.last.page, 1);
      expect(built.cubit.state.selectedTab, TripStatus.cancelled);
    });

    test('switchTab to the active tab does not ask again', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      await built.cubit.loadInitial();

      await built.cubit.switchTab(TripStatus.upcoming);

      expect(built.repository.queries, hasLength(1));
    });

    test('switching to a tab without a summary drops the summary', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      built.repository.onPage = (query) async => _page(
        [_booking(1, tab: query.tab)],
        summary: query.tab == TripStatus.completed
            ? const TripRecordSummary(
                totalCompletedTrips: 1,
                totalVisitedPois: 0,
              )
            : null,
      );

      await built.cubit.switchTab(TripStatus.completed);
      expect(built.cubit.state.summary, isNotNull);
      await built.cubit.switchTab(TripStatus.cancelled);

      expect(built.cubit.state.summary, isNull);
    });

    test('setTripType sends the filter and returns to page 1', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      built.repository.onPage = (_) async =>
          _page([_booking(1)], totalCount: 100);
      await built.cubit.loadInitial();
      await built.cubit.goToPage(3);

      await built.cubit.setTripType(TripRecordTypeFilter.selfPlannedItinerary);

      expect(
        built.repository.queries.last.tripType,
        TripRecordTypeFilter.selfPlannedItinerary,
      );
      expect(built.repository.queries.last.page, 1);
      expect(
        built.cubit.state.tripType,
        TripRecordTypeFilter.selfPlannedItinerary,
      );
    });

    test(
      'setDateRange sends the picked calendar days and returns to page 1',
      () async {
        final built = _build();
        addTearDown(built.cubit.close);
        built.repository.onPage = (_) async =>
            _page([_booking(1)], totalCount: 100);
        await built.cubit.loadInitial();
        await built.cubit.goToPage(2);

        // A DatePicker value is a local date; only its year, month and day count.
        await built.cubit.setDateRange(
          DateTime(2026, 10, 1, 13),
          DateTime(2026, 10, 31, 22),
        );

        final query = built.repository.queries.last;
        expect(query.startDate, DateTime.utc(2026, 10, 1));
        expect(query.endDate, DateTime.utc(2026, 10, 31));
        expect(query.page, 1);
        expect(built.cubit.state.validationError, isNull);
      },
    );

    test('a single-day range is valid', () async {
      final built = _build();
      addTearDown(built.cubit.close);

      await built.cubit.setDateRange(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 1),
      );

      expect(built.repository.queries, hasLength(1));
    });

    test(
      'a reversed range shows MSG29, asks for nothing and keeps the list',
      () async {
        final built = _build();
        addTearDown(built.cubit.close);
        await built.cubit.loadInitial();
        final before = built.cubit.state;

        await built.cubit.setDateRange(
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 1),
        );

        expect(built.repository.queries, hasLength(1));
        expect(
          built.cubit.state.validationError,
          TripHistoryStringsEn.validationDateRangeInvalid,
        );
        expect(built.cubit.state.items, before.items);
        expect(built.cubit.state.startDate, isNull);
      },
    );

    test(
      'clearDateRange removes the range, clears the message and refetches',
      () async {
        final built = _build();
        addTearDown(built.cubit.close);
        await built.cubit.setDateRange(
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
        );

        await built.cubit.clearDateRange();

        expect(built.repository.queries.last.startDate, isNull);
        expect(built.repository.queries.last.endDate, isNull);
        expect(built.cubit.state.startDate, isNull);
      },
    );

    test('clearFilters resets type and range in a single request', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      await built.cubit.setTripType(TripRecordTypeFilter.tourBooking);
      await built.cubit.setDateRange(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
      );
      final before = built.repository.queries.length;

      await built.cubit.clearFilters();

      expect(built.repository.queries.length, before + 1);
      final query = built.repository.queries.last;
      expect(query.tripType, TripRecordTypeFilter.all);
      expect(query.startDate, isNull);
      expect(query.endDate, isNull);
      expect(query.page, 1);
      expect(built.cubit.state.hasActiveFilters, isFalse);
    });
  });

  group('paging', () {
    test('goToPage asks for that page and keeps the filters', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      built.repository.onPage = (q) async =>
          _page([_booking(1)], page: q.page, totalCount: 100);
      await built.cubit.setTripType(TripRecordTypeFilter.tourBooking);

      await built.cubit.goToPage(3);

      expect(built.repository.queries.last.page, 3);
      expect(
        built.repository.queries.last.tripType,
        TripRecordTypeFilter.tourBooking,
      );
      expect(built.cubit.state.page, 3);
    });

    test('ignores pages outside 1..totalPages and the current page', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      built.repository.onPage = (_) async =>
          _page([_booking(1)], totalCount: 45);
      await built.cubit.loadInitial();

      await built.cubit.goToPage(0);
      await built.cubit.goToPage(4);
      await built.cubit.goToPage(1);

      expect(built.repository.queries, hasLength(1));
    });

    test(
      'never offers a page the backend would reject (page x size above 1000)',
      () async {
        final built = _build();
        addTearDown(built.cubit.close);
        built.repository.onPage = (_) async =>
            _page([_booking(1)], totalCount: 5000);

        await built.cubit.loadInitial();

        expect(built.cubit.state.totalPages, 50);
        await built.cubit.goToPage(51);
        expect(built.repository.queries, hasLength(1));
        await built.cubit.goToPage(50);
        expect(built.repository.queries.last.page, 50);
      },
    );
  });

  group('failures', () {
    final cases = <String, (Failure, String)>{
      'AuthenticationFailure': (
        const AuthenticationFailure(),
        TripHistoryStringsEn.permissionDenied,
      ),
      'PermissionFailure': (
        const PermissionFailure(),
        TripHistoryStringsEn.permissionDenied,
      ),
      'invalid date range': (
        const ValidationFailure('trip_history.invalid_date_range'),
        TripHistoryStringsEn.validationDateRangeInvalid,
      ),
      'other validation': (
        const ValidationFailure('trip_history.invalid_tab'),
        TripHistoryStringsEn.errorMessageGeneric,
      ),
      'NetworkFailure': (
        const NetworkFailure(),
        TripHistoryStringsEn.errorMessageGeneric,
      ),
      'ServerFailure with a code': (
        const ServerFailure('trip_history.invalid_response'),
        TripHistoryStringsEn.errorMessageGeneric,
      ),
      'NotFoundFailure': (
        const NotFoundFailure(),
        TripHistoryStringsEn.errorMessageGeneric,
      ),
    };

    for (final entry in cases.entries) {
      test('${entry.key} becomes a safe message', () async {
        final built = _build();
        addTearDown(built.cubit.close);
        built.repository.onPage = (_) async => throw entry.value.$1;

        await built.cubit.loadInitial();

        expect(built.cubit.state.status, TripRecordsStatus.failure);
        expect(built.cubit.state.errorMessage, entry.value.$2);
      });
    }

    test(
      'an unexpected exception is reported generically without its text',
      () async {
        final built = _build();
        addTearDown(built.cubit.close);
        built.repository.onPage = (_) async =>
            throw StateError('SELECT * FROM secrets');

        await built.cubit.loadInitial();

        expect(built.cubit.state.status, TripRecordsStatus.failure);
        expect(
          built.cubit.state.errorMessage,
          TripHistoryStringsEn.errorMessageGeneric,
        );
      },
    );

    test('retry asks for the same query again and recovers', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      built.repository.onPage = (_) async => throw const NetworkFailure();
      await built.cubit.switchTab(TripStatus.cancelled);
      expect(built.cubit.state.isFailure, isTrue);

      built.repository.onPage = (q) async => _page([_booking(7, tab: q.tab)]);
      await built.cubit.retry();

      expect(
        built.repository.queries.last,
        built.repository.queries[built.repository.queries.length - 2],
      );
      expect(built.cubit.state.status, TripRecordsStatus.success);
      expect(built.cubit.state.errorMessage, isNull);
      expect(built.cubit.state.items.single.id, 7);
    });

    test('switching to the active tab after a failure asks again', () async {
      final built = _build();
      addTearDown(built.cubit.close);
      built.repository.onPage = (_) async => throw const NetworkFailure();
      await built.cubit.loadInitial();
      built.repository.onPage = (_) async => _page([_booking(1)]);

      await built.cubit.switchTab(TripStatus.upcoming);

      expect(built.repository.queries, hasLength(2));
      expect(built.cubit.state.status, TripRecordsStatus.success);
    });

    test('has no pending-integration state', () {
      expect(
        TripRecordsStatus.values.map((s) => s.name),
        isNot(contains('pendingIntegration')),
      );
    });
  });

  group('overlapping requests', () {
    test(
      'a late answer to an earlier request never replaces a newer one',
      () async {
        final built = _build();
        addTearDown(built.cubit.close);
        final slow = Completer<TripRecordPage>();
        built.repository.onPage = (query) {
          if (query.tab == TripStatus.upcoming) return slow.future;
          return Future.value(_page([_booking(2, tab: query.tab)]));
        };

        final first = built.cubit.loadInitial();
        await built.cubit.switchTab(TripStatus.cancelled);
        slow.complete(_page([_booking(1)]));
        await first;

        expect(built.cubit.state.selectedTab, TripStatus.cancelled);
        expect(built.cubit.state.items.single.id, 2);
        expect(built.cubit.state.status, TripRecordsStatus.success);
      },
    );

    test(
      'a late failure of an earlier request does not overwrite a newer success',
      () async {
        final built = _build();
        addTearDown(built.cubit.close);
        final slow = Completer<TripRecordPage>();
        built.repository.onPage = (query) {
          if (query.tab == TripStatus.upcoming) return slow.future;
          return Future.value(_page([_booking(2, tab: query.tab)]));
        };

        final first = built.cubit.loadInitial();
        await built.cubit.switchTab(TripStatus.completed);
        slow.completeError(const NetworkFailure());
        await first;

        expect(built.cubit.state.status, TripRecordsStatus.success);
        expect(built.cubit.state.errorMessage, isNull);
      },
    );

    test('closing while a request is in flight does not throw', () async {
      final built = _build();
      final slow = Completer<TripRecordPage>();
      built.repository.onPage = (_) => slow.future;

      final load = built.cubit.loadInitial();
      await built.cubit.close();
      slow.complete(_page([_booking(1)]));

      await expectLater(load, completes);
    });
  });
}
