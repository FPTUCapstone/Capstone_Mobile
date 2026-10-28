import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/models/operator_bookings_json.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/usecases/operator_bookings_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/pages/operator_bookings_list_view.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/widgets/operator_bookings_filter_sheet.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';

import '../../operator_bookings_fixtures.dart';

OperatorBookingsPage _page(
  List<Map<String, Object?>> items, {
  int page = 1,
  int totalPages = 1,
  int? totalCount,
}) => OperatorBookingsJson.page(
  listPageJson(
    items: items,
    pageNumber: page,
    totalPages: totalPages,
    totalCount: totalCount ?? items.length,
  ),
);

final class _FakeRepository implements OperatorBookingsRepository {
  final List<OperatorBookingsQuery> queries = [];
  Future<OperatorBookingsPage> Function(OperatorBookingsQuery query)? onPage;
  Future<List<OperatorBookingTourOption>> Function()? onTours;

  @override
  Future<OperatorBookingsPage> getPage(OperatorBookingsQuery query) {
    queries.add(query);
    final handler = onPage;
    return handler == null
        ? Future.value(_page([listBookingJson()]))
        : handler(query);
  }

  @override
  Future<OperatorBookingDetail> getDetail(String bookingId) =>
      throw UnimplementedError();

  @override
  Future<List<OperatorBookingTourOption>> getTourOptions() {
    final handler = onTours;
    return handler == null
        ? Future.value(const [
            OperatorBookingTourOption(
              id: '101',
              title: 'Ba Na Hills full-day tour',
            ),
            OperatorBookingTourOption(id: '55', title: 'Food trail'),
          ])
        : handler();
  }
}

/// The vertical list (the status chips scroll horizontally in a Scrollable of their own).
final _listScrollable = find
    .byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axis == Axis.vertical,
    )
    .first;

void main() {
  late _FakeRepository repository;
  late OperatorBookingsCubit cubit;
  late List<String> visited;
  late List<Object?> extras;
  late List<String?> demoFlags;

  setUp(() {
    repository = _FakeRepository();
    cubit = OperatorBookingsCubit(
      listBookings: ListOperatorBookingsUseCase(repository),
      loadTourOptions: LoadOperatorBookingTourOptionsUseCase(repository),
    );
    visited = [];
    extras = [];
    demoFlags = [];
  });

  tearDown(() => cubit.close());

  void useSize(WidgetTester tester, Size size, {double textScale = 1}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> pump(
    WidgetTester tester, {
    bool isDemo = false,
    OperatorBookingDatePicker? pickDate,
    bool load = true,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: BlocProvider<OperatorBookingsCubit>.value(
              value: cubit,
              child: OperatorBookingsListView(
                isDemoMode: isDemo,
                pickDate: pickDate ?? pickOperatorBookingDate,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/operator/bookings/:bookingId',
          builder: (_, state) {
            visited.add(state.pathParameters['bookingId']!);
            extras.add(state.extra);
            demoFlags.add(state.uri.queryParameters['demo']);
            return const Scaffold(body: Text('detail page'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    if (load) {
      await cubit.loadInitial();
      await tester.pump();
    }
  }

  testWidgets(
    'shows a loading placeholder, not a pending-integration notice, while the first page loads',
    (tester) async {
      final gate = Completer<OperatorBookingsPage>();
      repository.onPage = (_) => gate.future;
      await pump(tester, load: false);
      unawaited(cubit.loadInitial());
      await tester.pump();

      expect(
        find.byKey(const Key('operator-bookings-loading')),
        findsOneWidget,
      );
      expect(find.textContaining('PENDING_BE_INTEGRATION'), findsNothing);

      gate.complete(_page([listBookingJson()]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('operator-bookings-loading')), findsNothing);
    },
  );

  testWidgets(
    'a card shows code, tour, departure day, booker, participants, total, status and check-in',
    (tester) async {
      await pump(tester);

      expect(find.text('BK-20261020-0007'), findsOneWidget);
      expect(find.text('Ba Na Hills full-day tour'), findsOneWidget);
      expect(find.textContaining('02/11/2026'), findsOneWidget);
      expect(find.textContaining('Nguyen Van A'), findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('2,400,000 VND'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(
        find.textContaining(
          OperatorBookingsStringsEn.notCheckedIn.toUpperCase(),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the summary strip shows the BE values as returned', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('37'), findsOneWidget);
    expect(find.text('112'), findsOneWidget);
    expect(find.text('98,400,000 VND'), findsOneWidget);
    expect(
      find.text(OperatorBookingsStringsEn.summaryBookings),
      findsOneWidget,
    );
  });

  testWidgets(
    'status chips include Expired and reload with the chosen status',
    (tester) async {
      await pump(tester);

      for (final label in [
        OperatorBookingsStringsEn.statusAll,
        OperatorBookingsStringsEn.statusPendingPayment,
        OperatorBookingsStringsEn.statusConfirmed,
        OperatorBookingsStringsEn.statusCompleted,
        OperatorBookingsStringsEn.statusCancelled,
        OperatorBookingsStringsEn.statusExpired,
      ]) {
        expect(
          find.widgetWithText(ChoiceChip, label),
          findsOneWidget,
          reason: label,
        );
      }

      final expired = find.widgetWithText(
        ChoiceChip,
        OperatorBookingsStringsEn.statusExpired,
      );
      // The chip row scrolls horizontally; the last chip may start off-screen.
      await tester.ensureVisible(expired);
      await tester.pumpAndSettle();
      await tester.tap(expired);
      await tester.pumpAndSettle();

      expect(repository.queries.last.status, OperatorBookingStatus.expired);
      expect(repository.queries.last.page, 1);
    },
  );

  testWidgets('submitting the search field searches by keyword', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '  alice ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.queries.last.keyword, 'alice');
  });

  testWidgets(
    'the search field never takes more than the 200 characters the backend accepts',
    (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'a' * 250);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, 200);
      expect(OperatorBookingsQuery.maxKeywordLength, 200);
    },
  );

  testWidgets(
    'the filter sheet lists the owned tours and applies the chosen one',
    (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip(OperatorBookingsStringsEn.filtersButton));
      await tester.pumpAndSettle();
      expect(find.text(OperatorBookingsStringsEn.filterTitle), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food trail').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          OperatorBookingsStringsEn.filterApply,
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.queries.last.tourId, '55');
      expect(find.text(OperatorBookingsStringsEn.filterTitle), findsNothing);
    },
  );

  testWidgets(
    'when the tour list failed the tour filter is disabled with a hint and the list still works',
    (tester) async {
      repository.onTours = () => Future.error(const ServerFailure());
      await pump(tester);

      expect(find.text('BK-20261020-0007'), findsOneWidget);
      await tester.tap(find.byTooltip(OperatorBookingsStringsEn.filtersButton));
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButtonFormField<String?>>(
        find.byType(DropdownButtonFormField<String?>),
      );
      expect(dropdown.onChanged, isNull);
      expect(
        find.text(OperatorBookingsStringsEn.filterToursUnavailable),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an inverted range in the sheet shows the MSG31 text, keeps the sheet open and sends nothing',
    (tester) async {
      final picks = [DateTime(2026, 11, 30), DateTime(2026, 11, 1)];
      await pump(tester, pickDate: (_, _) async => picks.removeAt(0));
      final calls = repository.queries.length;

      await tester.tap(find.byTooltip(OperatorBookingsStringsEn.filtersButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(OperatorBookingsStringsEn.filterDepartureFrom),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(OperatorBookingsStringsEn.filterDepartureTo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          OperatorBookingsStringsEn.filterApply,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(OperatorBookingsStringsEn.dateRangeInvalid),
        findsOneWidget,
      );
      expect(find.text(OperatorBookingsStringsEn.filterTitle), findsOneWidget);
      expect(repository.queries.length, calls);
    },
  );

  testWidgets(
    'a valid range applies as departure days and Reset clears the sheet filters in one request',
    (tester) async {
      final picks = [DateTime(2026, 11, 1), DateTime(2026, 11, 30)];
      await pump(tester, pickDate: (_, _) async => picks.removeAt(0));

      await tester.tap(find.byTooltip(OperatorBookingsStringsEn.filtersButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(OperatorBookingsStringsEn.filterDepartureFrom),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(OperatorBookingsStringsEn.filterDepartureTo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          OperatorBookingsStringsEn.filterApply,
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.queries.last.departureFrom, DateTime.utc(2026, 11, 1));
      expect(repository.queries.last.departureTo, DateTime.utc(2026, 11, 30));

      final calls = repository.queries.length;
      await tester.tap(find.byTooltip(OperatorBookingsStringsEn.filtersButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, OperatorBookingsStringsEn.filterReset),
      );
      await tester.pumpAndSettle();

      expect(repository.queries.length, calls + 1);
      expect(repository.queries.last.departureFrom, isNull);
      expect(repository.queries.last.departureTo, isNull);
    },
  );

  testWidgets('an empty result shows the no-records text', (tester) async {
    repository.onPage = (_) async => _page(const [], totalPages: 0);
    await pump(tester);

    expect(find.text(OperatorBookingsStringsEn.emptyTitle), findsOneWidget);
    expect(find.text(OperatorBookingsStringsEn.noRecords), findsOneWidget);
    expect(find.text(OperatorBookingsStringsEn.retry), findsNothing);
  });

  testWidgets('an access failure shows the permission text and no Retry', (
    tester,
  ) async {
    repository.onPage = (_) => Future.error(const PermissionFailure());
    await pump(tester);

    expect(find.text(OperatorBookingsStringsEn.accessDenied), findsOneWidget);
    expect(find.text(OperatorBookingsStringsEn.retry), findsNothing);
  });

  testWidgets(
    'a generic failure shows the system text and Retry reloads without any demo data',
    (tester) async {
      var attempt = 0;
      repository.onPage = (_) => ++attempt == 1
          ? Future.error(const NetworkFailure())
          : Future.value(_page([listBookingJson(code: 'BK-AFTER-RETRY')]));
      await pump(tester);

      expect(find.text(OperatorBookingsStringsEn.systemError), findsOneWidget);
      expect(find.text('BK-20261020-0007'), findsNothing);

      await tester.tap(find.text(OperatorBookingsStringsEn.retry));
      await tester.pumpAndSettle();

      expect(find.text('BK-AFTER-RETRY'), findsOneWidget);
      expect(find.text(OperatorBookingsStringsEn.systemError), findsNothing);
    },
  );

  testWidgets('Load more appends the next page and then disappears', (
    tester,
  ) async {
    repository.onPage = (query) async => query.page == 1
        ? _page(
            [listBookingJson(id: '1', code: 'BK-ONE')],
            totalPages: 2,
            totalCount: 2,
          )
        : _page(
            [listBookingJson(id: '2', code: 'BK-TWO')],
            page: 2,
            totalPages: 2,
            totalCount: 2,
          );
    await pump(tester);
    expect(find.text('BK-TWO'), findsNothing);

    await tester.scrollUntilVisible(
      find.text(OperatorBookingsStringsEn.loadMore),
      200,
      scrollable: _listScrollable,
    );
    await tester.tap(find.text(OperatorBookingsStringsEn.loadMore));
    await tester.pumpAndSettle();

    expect(find.text('BK-ONE'), findsOneWidget);
    expect(find.text('BK-TWO'), findsOneWidget);
    expect(find.text(OperatorBookingsStringsEn.loadMore), findsNothing);
  });

  testWidgets('a failed Load more keeps the rows and shows the system text', (
    tester,
  ) async {
    repository.onPage = (query) => query.page == 1
        ? Future.value(
            _page(
              [listBookingJson(id: '1', code: 'BK-ONE')],
              totalPages: 2,
              totalCount: 2,
            ),
          )
        : Future.error(const NetworkFailure());
    await pump(tester);

    await tester.scrollUntilVisible(
      find.text(OperatorBookingsStringsEn.loadMore),
      200,
      scrollable: _listScrollable,
    );
    await tester.tap(find.text(OperatorBookingsStringsEn.loadMore));
    await tester.pumpAndSettle();

    expect(find.text('BK-ONE'), findsOneWidget);
    expect(find.text(OperatorBookingsStringsEn.systemError), findsOneWidget);
  });

  testWidgets('tapping a card opens the detail route for that booking', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('BK-20261020-0007'));
    await tester.pumpAndSettle();

    expect(visited, ['1201']);
    expect(find.text('detail page'), findsOneWidget);
  });

  testWidgets(
    'the detail route gets the tapped card as its basics, and the demo flag only in demo mode',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('BK-20261020-0007'));
      await tester.pumpAndSettle();

      expect(extras.single, isA<OperatorBookingListItem>());
      expect((extras.single! as OperatorBookingListItem).bookingId, '1201');
      expect(demoFlags.single, isNull);

      await pump(tester, isDemo: true);
      await tester.tap(find.text('BK-20261020-0007'));
      await tester.pumpAndSettle();

      expect(demoFlags.last, 'true');
    },
  );

  testWidgets('pull to refresh reloads page 1', (tester) async {
    await pump(tester);
    final calls = repository.queries.length;

    await tester.fling(_listScrollable, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(repository.queries.length, calls + 1);
  });

  testWidgets('the demo banner shows only in demo mode', (tester) async {
    await pump(tester);
    expect(find.text(OperatorBookingsStringsEn.demoBanner), findsNothing);

    await pump(tester, isDemo: true);
    expect(find.text(OperatorBookingsStringsEn.demoBanner), findsOneWidget);
  });

  testWidgets(
    'offers no cancel, refund, check-in or pickup control (UC-41/42/43 are separate)',
    (tester) async {
      await pump(tester);

      for (final forbidden in [
        'check-in qr',
        'cancel booking',
        'refund',
        'pickup',
        'scan',
      ]) {
        expect(
          find.textContaining(RegExp(forbidden, caseSensitive: false)),
          findsNothing,
          reason: forbidden,
        );
      }
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    },
  );

  testWidgets(
    'fits a 320 dp wide screen at a large text scale without overflow',
    (tester) async {
      useSize(tester, const Size(320, 640), textScale: 2);
      repository.onPage = (_) async => _page([
        listBookingJson(
          tourTitle: 'A very long tour package name that keeps going and going',
          bookerName: 'Nguyen Thi Thanh Huong Phuong Lan',
        ),
      ]);
      await pump(tester);
      await tester.scrollUntilVisible(
        find.textContaining('very long tour'),
        200,
        scrollable: _listScrollable,
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('very long tour'), findsOneWidget);
    },
  );
}
