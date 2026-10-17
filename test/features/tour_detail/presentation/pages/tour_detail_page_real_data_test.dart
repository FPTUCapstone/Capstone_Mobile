import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/models/tour_detail_model.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/repositories/tour_detail_repository.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/usecases/get_tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_state.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/pages/tour_detail_page.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/resources/tour_detail_strings.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

Map<String, Object?> _schedule({
  required String id,
  required String start,
  required String end,
  Object? meetingPoint,
  Object? deadline,
  int adultPrice = 2890000,
  Object? childPrice,
  Object? infantPrice,
  Object? remaining,
  String status = 'available',
  bool bookable = true,
}) => {
  'scheduleId': id,
  'startAtUtc': start,
  'endAtUtc': end,
  'meetingPoint': meetingPoint,
  'registrationDeadlineAtUtc': deadline,
  'adultPrice': adultPrice,
  'childPrice': childPrice,
  'infantPrice': infantPrice,
  'remainingSlots': remaining,
  'availabilityStatus': status,
  'bookable': bookable,
};

/// Shaped like the seeded UAT "rich" tour: four departures in four states.
Map<String, Object?> richPayload() => {
  'tourId': '1',
  'title': 'Da Nang Discovery 3D2N',
  'description': 'Explore Da Nang, Son Tra and Hoi An.',
  'destination': 'Da Nang, Hoi An',
  'destinations': ['Da Nang', 'Hoi An'],
  'durationDays': 3,
  'basePrice': 2890000,
  'currency': 'VND',
  'operator': {'name': 'Central Vietnam Travel', 'contactPhone': '1900 1808'},
  'images': <Object?>[],
  'inclusions': '- Hotel\n- Guide',
  'exclusions': '- Flights',
  'cancellationPolicy': {
    'rules': [
      {'daysBeforeDeparture': 30, 'cancellationFeePercent': 0},
      {'daysBeforeDeparture': 15, 'cancellationFeePercent': 25},
      {'daysBeforeDeparture': 7, 'cancellationFeePercent': 50},
      {'daysBeforeDeparture': 0, 'cancellationFeePercent': 100},
    ],
  },
  'itinerary': [
    {
      'dayNo': 1,
      'items': [
        {
          'sequenceNo': 1,
          'poi': {
            'poiId': '11',
            'name': 'Marble Mountains',
            'address': '81 Huyen Tran Cong Chua',
            'latitude': 16.0,
            'longitude': 108.0,
          },
          'plannedTime': '08:30:00',
          'stayDurationMinutes': 90,
          'notes': 'Wear comfortable shoes',
        },
        {
          'sequenceNo': 2,
          'poi': {
            'poiId': '12',
            'name': 'Dragon Bridge',
            'address': null,
            'latitude': 16.06,
            'longitude': 108.22,
          },
          'plannedTime': null,
          'stayDurationMinutes': 30,
          'notes': null,
        },
      ],
    },
    {'dayNo': 2, 'items': <Object?>[]},
  ],
  'schedules': [
    _schedule(
      id: '501',
      start: '2026-11-06T01:00:00Z',
      end: '2026-11-08T10:00:00Z',
      meetingPoint: 'Sảnh khách sạn Mường Thanh, Đà Nẵng',
      deadline: '2026-11-05T17:00:00Z',
      childPrice: 900000,
      infantPrice: 0,
      remaining: 8,
    ),
    _schedule(
      id: '502',
      start: '2026-10-20T01:00:00Z',
      end: '2026-10-22T10:00:00Z',
      remaining: 5,
      bookable: false,
    ),
    _schedule(
      id: '503',
      start: '2026-12-01T01:00:00Z',
      end: '2026-12-03T10:00:00Z',
      remaining: 0,
      status: 'soldOut',
      bookable: false,
    ),
    _schedule(
      id: '504',
      start: '2026-12-20T01:00:00Z',
      end: '2026-12-22T10:00:00Z',
      status: 'unknown',
      bookable: false,
    ),
  ],
  'hasBookableSchedule': true,
  'rating': {'average': 4.5, 'count': 12},
  'asOfUtc': '2026-10-17T09:00:00Z',
};

TourDetail detailFrom(Map<String, Object?> payload) =>
    TourDetailModel.fromJson(payload).toEntity();

Widget buildPage({
  TourDetail? detail,
  Object? failure,
  TourDetailRepository? repository,
  double textScaleFactor = 1.0,
  AuthSessionCubit? authCubit,
  TourSummary? initialSummary,
}) {
  return BlocProvider<AuthSessionCubit>.value(
    value: authCubit ?? AuthSessionCubit(),
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
        child: TourDetailPage(
          tourId: '1',
          initialSummary: initialSummary,
          getTourDetail: GetTourDetail(
            repository ?? _Repository(detail, failure),
          ),
        ),
      ),
    ),
  );
}

final class _Repository implements TourDetailRepository {
  _Repository(this._detail, this._failure);

  final TourDetail? _detail;
  final Object? _failure;

  @override
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  }) async {
    final failure = _failure;
    if (failure != null) throw failure;
    return _detail;
  }
}

final class SwitchableRepository implements TourDetailRepository {
  SwitchableRepository({this.detail, this.failure});

  TourDetail? detail;
  Object? failure;
  int calls = 0;

  @override
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  }) async {
    calls++;
    final error = failure;
    if (error != null) throw error;
    return detail;
  }
}

/// Restores a signed-in Traveler the way the app does at launch.
Future<AuthSessionCubit> _signedInTraveler() async {
  final cubit = AuthSessionCubit(
    null,
    _MemoryStorage({
      AppConstants.accessTokenKey: 'access',
      AppConstants.refreshTokenKey: 'refresh',
      AppConstants.sessionRoleKey: 'traveler',
      AppConstants.keepSignedInKey: 'true',
    }),
  );
  await cubit.restoreSession();
  expect(cubit.state.isAuthenticated, isTrue);
  return cubit;
}

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this.values);

  final Map<String, String> values;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void _tall(WidgetTester tester, {Size size = const Size(390, 4000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('TourDetailPage with a real payload', () {
    testWidgets('renders every section of the contract', (tester) async {
      _tall(tester);
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Da Nang Discovery 3D2N'), findsOneWidget);
      expect(find.text('Central Vietnam Travel'), findsOneWidget);
      expect(find.text('Explore Da Nang, Son Tra and Hoi An.'), findsOneWidget);
      expect(find.text('Destinations: Da Nang • Hoi An'), findsOneWidget);
      expect(find.text('Contact Operator: 1900 1808'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('4.5 (12)'), findsOneWidget);

      // Itinerary stops
      expect(find.text(TourDetailStrings.itineraryTitle), findsOneWidget);
      expect(find.text('Marble Mountains'), findsOneWidget);
      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('81 Huyen Tran Cong Chua'), findsOneWidget);
      expect(find.text('Stay: 1 h 30 min'), findsOneWidget);
      expect(find.text('Wear comfortable shoes'), findsOneWidget);
      expect(find.text('Dragon Bridge'), findsOneWidget);
      expect(find.text('Stay: 30 min'), findsOneWidget);
      expect(find.text(TourDetailStrings.noStopsForDay), findsOneWidget);

      // Services
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);
      expect(find.text('Flights'), findsOneWidget);

      // Cancellation rules as notice ranges
      expect(
        find.text('Cancel 30 or more days before departure: free of charge'),
        findsOneWidget,
      );
      expect(
        find.text('Cancel 15 to 29 days before departure: 25% fee'),
        findsOneWidget,
      );
      expect(
        find.text('Cancel less than 7 days before departure: 100% fee'),
        findsOneWidget,
      );

      // Reviews: aggregate only
      expect(find.text(TourDetailState.msg128), findsNothing);
      expect(find.text('★ 4.5 (12)'), findsOneWidget);
      expect(find.text(TourDetailStrings.reviewsAggregateOnly), findsOneWidget);

      // Book Now
      expect(find.text(TourDetailStrings.bookNow), findsOneWidget);
    });

    testWidgets('shows each departure with its own real state', (tester) async {
      _tall(tester);
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();

      expect(find.text(TourDetailStrings.vietnamTimeNote), findsOneWidget);

      // Bookable departure, Vietnam time (01:00 UTC is 08:00).
      expect(find.text('06/11/2026 08:00 – 08/11/2026 17:00'), findsOneWidget);
      expect(find.text('8 slots remaining'), findsOneWidget);
      expect(
        find.text('Meeting point: Sảnh khách sạn Mường Thanh, Đà Nẵng'),
        findsOneWidget,
      );
      expect(find.text('Child: 900,000 VND'), findsOneWidget);
      expect(find.text('Infant: Free'), findsOneWidget);
      // 17:00 UTC is midnight in Vietnam: the deadline falls on the next date.
      expect(
        find.text('Registration closes: 06/11/2026 00:00'),
        findsOneWidget,
      );

      // Other states
      expect(find.text(TourDetailStrings.registrationClosed), findsOneWidget);
      expect(find.text(TourDetailStrings.soldOut), findsOneWidget);
      expect(find.text(TourDetailStrings.capacityUnknown), findsOneWidget);
    });

    testWidgets('a departure without optional details shows none of them', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();

      // Four departures, only one has a meeting point and child/infant prices.
      expect(find.textContaining('Meeting point:'), findsOneWidget);
      expect(find.textContaining('Child:'), findsOneWidget);
      expect(find.textContaining('Infant:'), findsOneWidget);
      expect(find.textContaining('Registration closes:'), findsOneWidget);
    });

    testWidgets('states that slot counts are a snapshot, not a reservation', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();

      // 09:00 UTC is 16:00 in Vietnam.
      expect(
        find.text(
          'Slot counts as of 17/10/2026 16:00 (Vietnam time). '
          'Availability is not a reservation.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tour with no ratings shows MSG128 and no aggregate', (
      tester,
    ) async {
      _tall(tester);
      final payload = richPayload()..['rating'] = {'average': null, 'count': 0};
      await tester.pumpWidget(buildPage(detail: detailFrom(payload)));
      await tester.pumpAndSettle();

      expect(find.text(TourDetailState.msg128), findsOneWidget);
      expect(find.text(TourDetailStrings.reviewsAggregateOnly), findsNothing);
      expect(find.textContaining('★'), findsNothing);
    });

    testWidgets('a minimal tour renders without optional content', (
      tester,
    ) async {
      _tall(tester);
      final payload = richPayload()
        ..['description'] = null
        ..['inclusions'] = null
        ..['exclusions'] = null
        ..['operator'] = {'name': 'Op'}
        ..['cancellationPolicy'] = {'rules': <Object?>[]}
        ..['itinerary'] = <Object?>[]
        ..['schedules'] = <Object?>[]
        ..['hasBookableSchedule'] = false
        ..['asOfUtc'] = '2026-10-17T09:00:00Z'
        ..['rating'] = {'average': null, 'count': 0};
      await tester.pumpWidget(buildPage(detail: detailFrom(payload)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(TourDetailStrings.noSchedules), findsOneWidget);
      expect(find.text(TourDetailStrings.noItinerary), findsOneWidget);
      expect(find.text(TourDetailStrings.noCancellationPolicy), findsOneWidget);
      expect(find.textContaining('Contact Operator'), findsNothing);
      expect(find.text(TourDetailStrings.inclusionsTitle), findsNothing);
      expect(find.text(TourDetailState.msg128), findsOneWidget);
      final book = tester.widget<FilledButton>(
        find.byKey(const Key('tour-detail-book-now-button')),
      );
      expect(book.onPressed, isNull);
    });

    testWidgets('long operator and place names do not overflow at 320 px', (
      tester,
    ) async {
      _tall(tester, size: const Size(320, 4000));
      final payload = richPayload()
        ..['operator'] = {
          'name': 'Công ty Du lịch Lữ hành Quốc tế Miền Trung Việt Nam',
          'contactPhone': '+84 236 3 888 888 (ext. 12345)',
        };
      await tester.pumpWidget(
        buildPage(detail: detailFrom(payload), textScaleFactor: 2.0),
      );
      await tester.pumpAndSettle();

      final error = tester.takeException();
      expect(error, isNull, reason: error?.toString());
    });

    testWidgets('departure cards expose date and state to screen readers', (
      tester,
    ) async {
      _tall(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();

      final label = tester.getSemantics(find.byKey(const Key('schedule-503')));
      expect(label.label, contains('01/12/2026 08:00'));
      expect(label.label, contains(TourDetailStrings.soldOut));
      handle.dispose();
    });
  });

  group('Book Now and states', () {
    Finder bookNow() => find.byKey(const Key('tour-detail-book-now-button'));
    FilledButton bookNowButton(WidgetTester tester) =>
        tester.widget<FilledButton>(bookNow());

    testWidgets('a bookable departure is preselected and Book Now is on', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();

      expect(bookNowButton(tester).onPressed, isNotNull);
      expect(find.text(TourDetailStrings.bookNow), findsOneWidget);
      expect(find.text(TourDetailState.msg65), findsNothing);
    });

    testWidgets('a guest is asked to sign in, in production mode', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();

      await tester.tap(bookNow());
      await tester.pumpAndSettle();

      expect(find.text(TourDetailStrings.loginRequiredTitle), findsOneWidget);
      expect(find.text(TourDetailStrings.loginAction), findsOneWidget);
      expect(find.text(TourDetailStrings.loginLater), findsOneWidget);
    });

    testWidgets('Maybe Later closes the dialog and keeps the page', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();
      await tester.tap(bookNow());
      await tester.pumpAndSettle();

      await tester.tap(find.text(TourDetailStrings.loginLater));
      await tester.pumpAndSettle();

      expect(find.text(TourDetailStrings.loginRequiredTitle), findsNothing);
      expect(find.text('Da Nang Discovery 3D2N'), findsOneWidget);
    });

    testWidgets('a signed-in traveler reaches the booking handoff', (
      tester,
    ) async {
      _tall(tester);
      final session = await _signedInTraveler();
      addTearDown(session.close);
      await tester.pumpWidget(
        buildPage(detail: detailFrom(richPayload()), authCubit: session),
      );
      await tester.pumpAndSettle();

      await tester.tap(bookNow());
      await tester.pumpAndSettle();

      expect(find.text(TourDetailStrings.bookingWorkflowTitle), findsOneWidget);
      expect(find.text(TourDetailStrings.loginRequiredTitle), findsNothing);
    });

    testWidgets('selecting a closed departure disables Book Now and says why', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('schedule-502')));
      await tester.pumpAndSettle();

      expect(bookNowButton(tester).onPressed, isNull);
      expect(find.text(TourDetailState.msg65), findsOneWidget);
      // The bar names the real reason, not a generic "Sold Out".
      expect(
        find.descendant(
          of: bookNow(),
          matching: find.text(TourDetailStrings.registrationClosed),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('schedule-501')));
      await tester.pumpAndSettle();
      expect(bookNowButton(tester).onPressed, isNotNull);
      expect(find.text(TourDetailState.msg65), findsNothing);
    });

    testWidgets('sold out and unknown departures cannot be booked', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(buildPage(detail: detailFrom(richPayload())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('schedule-503')));
      await tester.pumpAndSettle();
      expect(bookNowButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const Key('schedule-504')));
      await tester.pumpAndSettle();
      expect(bookNowButton(tester).onPressed, isNull);
      expect(
        find.descendant(
          of: bookNow(),
          matching: find.text(TourDetailStrings.capacityUnknown),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no bookable departure: MSG65 up front, Book Now off', (
      tester,
    ) async {
      _tall(tester);
      final payload = richPayload();
      final schedules = (payload['schedules']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .where((schedule) => schedule['scheduleId'] != '501')
          .toList();
      payload
        ..['schedules'] = schedules
        ..['hasBookableSchedule'] = false;
      await tester.pumpWidget(buildPage(detail: detailFrom(payload)));
      await tester.pumpAndSettle();

      expect(find.text(TourDetailState.msg65), findsOneWidget);
      expect(bookNowButton(tester).onPressed, isNull);
    });

    testWidgets('a missing tour shows the unavailable text without Retry', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text(TourDetailStrings.notFoundTitle), findsOneWidget);
      expect(find.text(TourDetailState.notFoundMessage), findsOneWidget);
      expect(find.text(TourDetailStrings.retry), findsNothing);
      expect(
        find.byKey(const Key('tour-detail-back-to-list-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('tour-detail-book-now-button')),
        findsNothing,
      );
    });

    testWidgets('a failure shows MSG127 with Retry that reloads', (
      tester,
    ) async {
      _tall(tester);
      final repository = SwitchableRepository(failure: Exception('offline'));
      await tester.pumpWidget(buildPage(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text(TourDetailStrings.errorTitle), findsOneWidget);
      expect(find.text(TourDetailState.msg127), findsOneWidget);
      expect(find.text(TourDetailStrings.notFoundTitle), findsNothing);
      expect(
        find.byKey(const Key('tour-detail-book-now-button')),
        findsNothing,
      );
      expect(repository.calls, 1);

      repository
        ..failure = null
        ..detail = detailFrom(richPayload());
      await tester.tap(find.byKey(const Key('tour-detail-retry-button')));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.text('Da Nang Discovery 3D2N'), findsOneWidget);
      expect(find.text(TourDetailStrings.errorTitle), findsNothing);
    });

    testWidgets('Retry that fails again stays on the error view', (
      tester,
    ) async {
      final repository = SwitchableRepository(failure: Exception('offline'));
      await tester.pumpWidget(buildPage(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tour-detail-retry-button')));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.text(TourDetailState.msg127), findsOneWidget);
    });

    testWidgets('an unexpected error never leaks its text', (tester) async {
      await tester.pumpWidget(
        buildPage(failure: const FormatException('secret internal detail')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('secret internal detail'), findsNothing);
      expect(find.text(TourDetailState.msg127), findsOneWidget);
    });

    testWidgets('loading is announced to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final repository = SwitchableRepository(
        detail: detailFrom(richPayload()),
      );
      await tester.pumpWidget(buildPage(repository: repository));

      expect(
        find.bySemanticsLabel(TourDetailStrings.loadingLabel),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });
}
