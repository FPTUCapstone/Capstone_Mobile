import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/repositories/operator_bookings_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/usecases/operator_bookings_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_state.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';

OperatorBookingListItem _item(
  String id, {
  OperatorBookingStatus status = OperatorBookingStatus.confirmed,
}) => OperatorBookingListItem(
  bookingId: id,
  bookingCode: 'BK-$id',
  tour: const OperatorBookingTour(tourId: '101', title: 'Ba Na Hills'),
  schedule: OperatorBookingSchedule(
    scheduleId: '311',
    startAtUtc: DateTime.utc(2026, 11, 2),
    endAtUtc: DateTime.utc(2026, 11, 2, 10),
  ),
  booker: const OperatorBookingBooker(
    userId: '55',
    fullName: 'Nguyen Van A',
    email: 'a@example.com',
  ),
  quantity: 2,
  totalAmount: 1000000,
  discountAmount: 0,
  status: status,
  paymentStatus: OperatorPaymentStatus.paid,
  checkInStatus: OperatorCheckInStatus.notCheckedIn,
  bookedAtUtc: DateTime.utc(2026, 10, 20),
);

OperatorBookingsPage _page(
  List<OperatorBookingListItem> items, {
  int page = 1,
  int totalPages = 1,
  int? totalCount,
  OperatorBookingsSummary summary = const OperatorBookingsSummary(
    totalBookings: 37,
    totalParticipants: 112,
    totalConfirmedAmount: 98400000,
  ),
}) => OperatorBookingsPage(
  items: items,
  summary: summary,
  page: page,
  pageSize: 20,
  totalCount: totalCount ?? items.length,
  totalPages: totalPages,
);

final class _FakeRepository implements OperatorBookingsRepository {
  final List<OperatorBookingsQuery> queries = [];
  Future<OperatorBookingsPage> Function(OperatorBookingsQuery query)? onPage;
  Future<List<OperatorBookingTourOption>> Function()? onTours;
  int tourCalls = 0;

  @override
  Future<OperatorBookingsPage> getPage(OperatorBookingsQuery query) {
    queries.add(query);
    final handler = onPage;
    return handler == null ? Future.value(_page([_item('1')])) : handler(query);
  }

  @override
  Future<OperatorBookingDetail> getDetail(String bookingId) =>
      throw UnimplementedError();

  @override
  Future<List<OperatorBookingTourOption>> getTourOptions() {
    tourCalls++;
    final handler = onTours;
    return handler == null
        ? Future.value(const [
            OperatorBookingTourOption(id: '101', title: 'Ba Na Hills'),
          ])
        : handler();
  }
}

OperatorBookingsCubit _cubit(_FakeRepository repository) =>
    OperatorBookingsCubit(
      listBookings: ListOperatorBookingsUseCase(repository),
      loadTourOptions: LoadOperatorBookingTourOptionsUseCase(repository),
    );

void main() {
  late _FakeRepository repository;
  late OperatorBookingsCubit cubit;

  setUp(() {
    repository = _FakeRepository();
    cubit = _cubit(repository);
  });

  tearDown(() => cubit.close());

  group('loadInitial', () {
    test(
      'starts loading, then shows the BE page and summary as returned',
      () async {
        repository.onPage = (_) async =>
            _page([_item('1'), _item('2')], totalPages: 2, totalCount: 37);
        final states = <OperatorBookingsState>[];
        final subscription = cubit.stream.listen(states.add);

        await cubit.loadInitial();
        await subscription.cancel();

        expect(states.first.status, OperatorBookingsStatus.loading);
        expect(cubit.state.status, OperatorBookingsStatus.success);
        expect(cubit.state.items.map((item) => item.bookingId), ['1', '2']);
        expect(cubit.state.summary.totalBookings, 37);
        expect(cubit.state.summary.totalParticipants, 112);
        expect(cubit.state.summary.totalConfirmedAmount, 98400000);
        expect(cubit.state.totalCount, 37);
        expect(cubit.state.hasMore, isTrue);
        expect(repository.queries.single, const OperatorBookingsQuery());
      },
    );

    test('loads the tour options next to the list', () async {
      await cubit.loadInitial();

      expect(cubit.state.tourOptions.single.id, '101');
      expect(cubit.state.tourOptionsFailed, isFalse);
      expect(repository.tourCalls, 1);
    });

    test(
      'a failed tour list only disables the tour filter; the list still loads',
      () async {
        repository.onTours = () => Future.error(const ServerFailure());

        await cubit.loadInitial();

        expect(cubit.state.status, OperatorBookingsStatus.success);
        expect(cubit.state.items, isNotEmpty);
        expect(cubit.state.tourOptions, isEmpty);
        expect(cubit.state.tourOptionsFailed, isTrue);
      },
    );

    test(
      'an empty result is a success with an empty list (MSG128 is a view decision)',
      () async {
        repository.onPage = (_) async => _page(
          const [],
          totalPages: 0,
          summary: OperatorBookingsSummary.empty,
        );

        await cubit.loadInitial();

        expect(cubit.state.status, OperatorBookingsStatus.success);
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.hasMore, isFalse);
        expect(cubit.state.summary, OperatorBookingsSummary.empty);
      },
    );
  });

  group('filters', () {
    test(
      'a status chip reloads page 1 with that status, and null means all',
      () async {
        await cubit.loadInitial();

        await cubit.selectStatus(OperatorBookingStatus.expired);
        expect(repository.queries.last.status, OperatorBookingStatus.expired);
        expect(repository.queries.last.page, 1);
        expect(cubit.state.status, OperatorBookingsStatus.success);
        expect(cubit.state.selectedStatus, OperatorBookingStatus.expired);

        await cubit.selectStatus(null);
        expect(repository.queries.last.status, isNull);
        expect(cubit.state.selectedStatus, isNull);
      },
    );

    test(
      'choosing the status that is already selected does not reload',
      () async {
        await cubit.loadInitial();
        await cubit.selectStatus(OperatorBookingStatus.confirmed);
        final calls = repository.queries.length;

        await cubit.selectStatus(OperatorBookingStatus.confirmed);

        expect(repository.queries.length, calls);
      },
    );

    test(
      'a search reloads page 1 with the trimmed keyword and keeps the other filters',
      () async {
        await cubit.loadInitial();
        await cubit.selectStatus(OperatorBookingStatus.confirmed);

        await cubit.search('  alice  ');

        expect(repository.queries.last.keyword, 'alice');
        expect(repository.queries.last.status, OperatorBookingStatus.confirmed);
        expect(repository.queries.last.page, 1);
        expect(cubit.state.keyword, 'alice');
      },
    );

    test('a blank search clears the keyword', () async {
      await cubit.loadInitial();
      await cubit.search('alice');

      await cubit.search('   ');

      expect(repository.queries.last.keyword, isNull);
      expect(cubit.state.keyword, isNull);
    });

    test('tour and departure range apply together, as calendar days', () async {
      await cubit.loadInitial();

      await cubit.applyFilters(
        tourId: '101',
        departureFrom: DateTime(2026, 11, 1, 18),
        departureTo: DateTime(2026, 11, 30, 3),
      );

      final query = repository.queries.last;
      expect(query.tourId, '101');
      expect(query.departureFrom, DateTime.utc(2026, 11, 1));
      expect(query.departureTo, DateTime.utc(2026, 11, 30));
      expect(query.page, 1);
      expect(cubit.state.tourId, '101');
      expect(cubit.state.validationError, isNull);
    });

    test(
      'an inverted range shows the MSG31 text, keeps the list and sends no request',
      () async {
        await cubit.loadInitial();
        final calls = repository.queries.length;
        final before = cubit.state.items;

        await cubit.applyFilters(
          departureFrom: DateTime(2026, 11, 30),
          departureTo: DateTime(2026, 11, 1),
        );

        expect(repository.queries.length, calls);
        expect(cubit.state.items, before);
        expect(
          cubit.state.validationError,
          OperatorBookingsStringsEn.dateRangeInvalid,
        );
        expect(cubit.state.departureFrom, isNull);
      },
    );

    test(
      'a valid range after an inverted one clears the validation message',
      () async {
        await cubit.loadInitial();
        await cubit.applyFilters(
          departureFrom: DateTime(2026, 11, 30),
          departureTo: DateTime(2026, 11, 1),
        );

        await cubit.applyFilters(
          departureFrom: DateTime(2026, 11, 1),
          departureTo: DateTime(2026, 11, 30),
        );

        expect(cubit.state.validationError, isNull);
      },
    );

    test('clearFilters resets the tour and the range in one request', () async {
      await cubit.loadInitial();
      await cubit.applyFilters(
        tourId: '101',
        departureFrom: DateTime(2026, 11, 1),
        departureTo: DateTime(2026, 11, 30),
      );
      await cubit.selectStatus(OperatorBookingStatus.confirmed);
      final calls = repository.queries.length;

      await cubit.clearFilters();

      expect(repository.queries.length, calls + 1);
      expect(repository.queries.last.tourId, isNull);
      expect(repository.queries.last.departureFrom, isNull);
      expect(repository.queries.last.departureTo, isNull);
      // The status chip and the search belong to the list screen, not to the sheet.
      expect(repository.queries.last.status, OperatorBookingStatus.confirmed);
    });
  });

  group('loadMore', () {
    setUp(() {
      repository.onPage = (query) async => query.page == 1
          ? _page([_item('1'), _item('2')], totalPages: 2, totalCount: 3)
          : _page([_item('3')], page: 2, totalPages: 2, totalCount: 3);
    });

    test('appends the next page with the same filters', () async {
      await cubit.loadInitial();
      await cubit.selectStatus(OperatorBookingStatus.confirmed);

      await cubit.loadMore();

      expect(repository.queries.last.page, 2);
      expect(repository.queries.last.status, OperatorBookingStatus.confirmed);
      expect(cubit.state.items.map((item) => item.bookingId), ['1', '2', '3']);
      expect(cubit.state.page, 2);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.loadingMore, isFalse);
    });

    test('never duplicates a booking that appears on two pages', () async {
      repository.onPage = (query) async => query.page == 1
          ? _page([_item('1'), _item('2')], totalPages: 2, totalCount: 3)
          : _page(
              [_item('2'), _item('3')],
              page: 2,
              totalPages: 2,
              totalCount: 3,
            );
      await cubit.loadInitial();

      await cubit.loadMore();

      expect(cubit.state.items.map((item) => item.bookingId), ['1', '2', '3']);
    });

    test('is ignored when there is no next page', () async {
      repository.onPage = (_) async => _page([_item('1')]);
      await cubit.loadInitial();
      final calls = repository.queries.length;

      await cubit.loadMore();

      expect(repository.queries.length, calls);
    });

    test('is ignored while another load more is in flight', () async {
      await cubit.loadInitial();
      final gate = Completer<OperatorBookingsPage>();
      repository.onPage = (_) => gate.future;
      final first = cubit.loadMore();
      final calls = repository.queries.length;

      await cubit.loadMore();
      gate.complete(_page([_item('3')], page: 2, totalPages: 2, totalCount: 3));
      await first;

      expect(repository.queries.length, calls);
    });

    test(
      'a filter change while a page is loading drops that late page',
      () async {
        await cubit.loadInitial();
        final late = Completer<OperatorBookingsPage>();
        repository.onPage = (query) =>
            query.page == 2 ? late.future : Future.value(_page([_item('9')]));
        final pending = cubit.loadMore();

        await cubit.selectStatus(OperatorBookingStatus.cancelled);
        late.complete(
          _page([_item('3')], page: 2, totalPages: 2, totalCount: 3),
        );
        await pending;

        expect(cubit.state.items.map((item) => item.bookingId), ['9']);
        expect(cubit.state.loadingMore, isFalse);
      },
    );

    test(
      'a failure keeps the rows already shown and reports it without discarding them',
      () async {
        await cubit.loadInitial();
        repository.onPage = (_) => Future.error(const NetworkFailure());

        await cubit.loadMore();

        expect(cubit.state.status, OperatorBookingsStatus.success);
        expect(cubit.state.items.map((item) => item.bookingId), ['1', '2']);
        expect(cubit.state.loadingMore, isFalse);
        expect(
          cubit.state.loadMoreError,
          OperatorBookingsStringsEn.systemError,
        );
      },
    );
  });

  group('stale and closed', () {
    test('a newer request supersedes an older answer', () async {
      final slow = Completer<OperatorBookingsPage>();
      var call = 0;
      repository.onPage = (_) =>
          ++call == 1 ? slow.future : Future.value(_page([_item('fast')]));
      final first = cubit.loadInitial();

      await cubit.selectStatus(OperatorBookingStatus.completed);
      slow.complete(_page([_item('slow')]));
      await first;

      expect(cubit.state.items.map((item) => item.bookingId), ['fast']);
    });

    test(
      'a late answer after close changes nothing and throws nothing',
      () async {
        final gate = Completer<OperatorBookingsPage>();
        repository.onPage = (_) => gate.future;
        final loading = cubit.loadInitial();

        await cubit.close();
        gate.complete(_page([_item('1')]));

        await loading;
      },
    );
  });

  group('failures', () {
    for (final (label, failure) in <(String, Failure)>[
      ('a 401', const AuthenticationFailure()),
      ('a 403', const PermissionFailure()),
      ('a 404', const NotFoundFailure()),
    ]) {
      test('$label is the access message and cannot be retried', () async {
        repository.onPage = (_) => Future.error(failure);

        await cubit.loadInitial();

        expect(cubit.state.status, OperatorBookingsStatus.failure);
        expect(
          cubit.state.errorMessage,
          OperatorBookingsStringsEn.accessDenied,
        );
        expect(cubit.state.canRetry, isFalse);
        expect(cubit.state.items, isEmpty);
      });
    }

    for (final (label, failure) in <(String, Failure)>[
      ('a network failure', const NetworkFailure()),
      ('a server failure', const ServerFailure('private detail')),
      ('a malformed body', const ServerFailure(operatorBookingInvalidResponse)),
      ('an unknown failure', const UnknownFailure()),
    ]) {
      test(
        '$label is the generic message with Retry and never exposes details',
        () async {
          repository.onPage = (_) => Future.error(failure);

          await cubit.loadInitial();

          expect(cubit.state.status, OperatorBookingsStatus.failure);
          expect(
            cubit.state.errorMessage,
            OperatorBookingsStringsEn.systemError,
          );
          expect(cubit.state.canRetry, isTrue);
        },
      );
    }

    test('a backend date-range rejection shows the MSG31 text', () async {
      repository.onPage = (_) => Future.error(
        const ValidationFailure(operatorBookingInvalidDateRange),
      );

      await cubit.loadInitial();

      expect(
        cubit.state.errorMessage,
        OperatorBookingsStringsEn.dateRangeInvalid,
      );
    });

    test('retry reloads page 1 with the filters that were in place', () async {
      repository.onPage = (_) => Future.error(const NetworkFailure());
      await cubit.loadInitial();
      await cubit.selectStatus(OperatorBookingStatus.confirmed);
      repository.onPage = (_) async => _page([_item('7')]);

      await cubit.retry();

      expect(repository.queries.last.status, OperatorBookingStatus.confirmed);
      expect(cubit.state.status, OperatorBookingsStatus.success);
      expect(cubit.state.items.map((item) => item.bookingId), ['7']);
      expect(cubit.state.errorMessage, isNull);
    });

    test('refresh reloads page 1 without clearing the filters', () async {
      await cubit.loadInitial();
      await cubit.selectStatus(OperatorBookingStatus.confirmed);

      await cubit.refresh();

      expect(repository.queries.last.page, 1);
      expect(repository.queries.last.status, OperatorBookingStatus.confirmed);
    });
  });
}
