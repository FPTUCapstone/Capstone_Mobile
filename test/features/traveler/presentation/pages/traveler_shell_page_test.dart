import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/notifications/domain/entities/in_app_notification.dart';
import 'package:trip_mate_mobile/features/notifications/domain/repositories/in_app_notification_realtime.dart';
import 'package:trip_mate_mobile/features/notifications/domain/repositories/in_app_notification_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/explore_poi_page.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/paged_tour_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_search_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/pages/tour_search_page.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/traveler_profile_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/traveler_profile_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_shell_page.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/repositories/traveler_emergency_repository.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/usecases/traveler_emergency_use_cases.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_notices_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sliding_bottom_nav.dart';

import '../../../operator_weather_safety/support/fake_operator_weather_safety_repository.dart';
import '../cubit/my_trips_cubit_test.dart';

class _ProfileRepository implements TravelerProfileRepository {
  @override
  Future<TravelerProfile> load() async => const TravelerProfile(
    fullName: 'Traveler',
    email: 'traveler@example.com',
  );

  @override
  Future<TravelerProfile> save({
    required String fullName,
    required String phoneNumber,
    String? dateOfBirth,
    Uint8List? avatar,
    String? avatarName,
    String? avatarMime,
  }) async => TravelerProfile(
    fullName: fullName,
    email: 'traveler@example.com',
    phoneNumber: phoneNumber,
  );
}

Future<AuthSessionCubit> _authenticatedCubit({
  _RecordingAuthRepository? repository,
  _MemoryStorage? storage,
}) async {
  final cubit = AuthSessionCubit(
    repository ?? _RecordingAuthRepository(),
    storage ??
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

Future<void> _pumpShell(WidgetTester tester, AuthSessionCubit cubit) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider<AuthSessionCubit>.value(
        value: cubit,
        child: const TravelerShellPage(),
      ),
    ),
  );
}

void main() {
  late FakeItineraryListRepository tripRepository;

  setUp(() async {
    await serviceLocator.reset();
    tripRepository = FakeItineraryListRepository({
      1: tripPage([tripSummary(60014, openSessionId: 11)]),
    });
    serviceLocator
      ..registerFactory<TravelerProfileCubit>(
        () => TravelerProfileCubit(_ProfileRepository()),
      )
      ..registerFactory<PoiListCubit>(
        () => PoiListCubit(getPois: GetPoisUseCase(_EmptyPoiRepository())),
      )
      ..registerFactory<MyTripsCubit>(
        () => MyTripsCubit(repository: tripRepository),
      )
      ..registerFactory<TourSearchCubit>(
        () => TourSearchCubit(
          searchTours: SearchToursUseCase(_EmptyTourRepository()),
        ),
      );
  });

  tearDown(serviceLocator.reset);

  testWidgets('leaving the shell keeps notices until the session ends', (
    tester,
  ) async {
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);
    final notices = TravelerEmergencyNoticesCubit(
      getNotices: GetTravelerEmergencyNoticesUseCase(_NoticeRepository()),
      networkInfo: FakeNetworkInfo(),
    );
    addTearDown(notices.close);
    serviceLocator.registerSingleton<TravelerEmergencyNoticesCubit>(notices);
    final router = GoRouter(
      initialLocation: AppRoutes.traveler,
      routes: [
        GoRoute(
          path: AppRoutes.traveler,
          builder: (_, _) => BlocProvider<AuthSessionCubit>.value(
            value: cubit,
            child: const TravelerShellPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.tripHistory,
          builder: (_, _) => const Scaffold(body: Text('History')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(notices.state.hasNoticeFor(42), isTrue);

    router.go(AppRoutes.tripHistory);
    await tester.pumpAndSettle();
    expect(notices.state.hasNoticeFor(42), isTrue);

    router.go(AppRoutes.traveler);
    await tester.pumpAndSettle();
    await cubit.handleSessionExpired();
    router.go(AppRoutes.tripHistory);
    await tester.pumpAndSettle();
    expect(notices.state.hasNoticeFor(42), isFalse);
  });

  testWidgets('notification icon opens the traveler inbox route', (
    tester,
  ) async {
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: AppRoutes.traveler,
      routes: [
        GoRoute(
          path: AppRoutes.traveler,
          builder: (_, _) => BlocProvider<AuthSessionCubit>.value(
            value: cubit,
            child: const TravelerShellPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.inAppInbox,
          name: AppRouteNames.inAppInbox,
          builder: (_, _) => const Scaffold(body: Text('Inbox destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Inbox destination'), findsOneWidget);
  });

  testWidgets(
    'notification bell shows unread badge count and refreshes on return from inbox',
    (tester) async {
      final inboxRepo = _FakeUnreadInboxRepository(
        items: [
          _unreadNotice(1),
          _unreadNotice(2),
        ],
      );
      serviceLocator.registerSingleton<InAppNotificationRepository>(inboxRepo);
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);
      final router = GoRouter(
        initialLocation: AppRoutes.traveler,
        routes: [
          GoRoute(
            path: AppRoutes.traveler,
            builder: (_, _) => BlocProvider<AuthSessionCubit>.value(
              value: cubit,
              child: const TravelerShellPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.inAppInbox,
            name: AppRouteNames.inAppInbox,
            builder: (_, _) => const Scaffold(body: Text('Inbox destination')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final badgeBefore = tester.widget<Badge>(find.byType(Badge));
      expect(badgeBefore.isLabelVisible, isTrue);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('traveler_inbox_nav_button')));
      await tester.pumpAndSettle();
      expect(find.text('Inbox destination'), findsOneWidget);

      // Simulate user reading all notifications in inbox before popping back.
      inboxRepo.items = const [];
      router.pop();
      await tester.pumpAndSettle();

      final badgeAfter = tester.widget<Badge>(find.byType(Badge));
      expect(badgeAfter.isLabelVisible, isFalse);
    },
  );

  testWidgets('notification bell caps badge at 50+ when more unread pages exist', (
    tester,
  ) async {
    final inboxRepo = _FakeUnreadInboxRepository(
      items: List.generate(50, (i) => _unreadNotice(i + 1)),
      nextBeforeId: 100,
    );
    serviceLocator.registerSingleton<InAppNotificationRepository>(inboxRepo);
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);

    await _pumpShell(tester, cubit);
    await tester.pumpAndSettle();

    expect(find.text('50+'), findsOneWidget);
  });

  testWidgets('notification bell updates badge in real time on hub change hint', (
    tester,
  ) async {
    final inboxRepo = _FakeUnreadInboxRepository(items: [_unreadNotice(1)]);
    final realtime = _FakeNotificationRealtime();
    serviceLocator
      ..registerSingleton<InAppNotificationRepository>(inboxRepo)
      ..registerSingleton<InAppNotificationRealtime>(realtime);
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);

    await _pumpShell(tester, cubit);
    await tester.pumpAndSettle();

    expect(realtime.startCalls, 1);
    expect(find.text('1'), findsOneWidget);

    inboxRepo.items = [_unreadNotice(1), _unreadNotice(2)];
    realtime.emitChange();
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(realtime.disposeCalls, 1);
  });

  testWidgets('support action opens general help from the traveler shell', (
    tester,
  ) async {
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: AppRoutes.traveler,
      routes: [
        GoRoute(
          path: AppRoutes.traveler,
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const TravelerShellPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.supportChat,
          builder: (_, state) {
            expect(state.extra, isNull);
            return const Scaffold(body: Text('General support destination'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byTooltip('Hỗ trợ'));
    await tester.pumpAndSettle();
    expect(find.text('General support destination'), findsOneWidget);
  });

  testWidgets('trips tab lists the traveler itineraries on each visit', (
    tester,
  ) async {
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.text('Chuyến đi'));
    await tester.pumpAndSettle();

    expect(find.text('Trip 60014'), findsOneWidget);
    expect(find.text('Đang dẫn đường'), findsOneWidget);
    expect(find.text('Feature placeholder'), findsNothing);

    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyến đi'));
    await tester.pumpAndSettle();
    expect(tripRepository.requestedPages, [1, 1]);
  });

  testWidgets(
    'renders localized Tour Search and Tour Recommendations quick actions on Home tab',
    (tester) async {
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);
      await _pumpShell(tester, cubit);
      await tester.pumpAndSettle();

      expect(find.text('Tìm tour'), findsOneWidget);
      expect(find.text('Xin chào, Traveler'), findsOneWidget);
      expect(find.textContaining('Nguyen Minh Phuc'), findsNothing);
      expect(find.text('Gợi ý tour'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsNothing);
    },
  );

  testWidgets(
    'traveler profile sign-out confirms and uses the backend-integrated flow once',
    (tester) async {
      final repository = _RecordingAuthRepository();
      final cubit = await _authenticatedCubit(repository: repository);
      addTearDown(cubit.close);
      await _pumpShell(tester, cubit);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      final signOutButton = find.byKey(
        const Key('traveler-profile-sign-out-button'),
      );
      await tester.scrollUntilVisible(
        signOutButton,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(signOutButton);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
      await tester.pumpAndSettle();

      expect(repository.logoutCalls, 1);
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    },
  );

  testWidgets('traveler profile sign-out action is disabled while in flight', (
    tester,
  ) async {
    final completer = Completer<void>();
    final repository = _RecordingAuthRepository(logoutCompleter: completer);
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    final signOutButton = find.byKey(
      const Key('traveler-profile-sign-out-button'),
    );
    await tester.scrollUntilVisible(
      signOutButton,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(signOutButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pump();

    // Busy state is derived from the approved Cubit marker, not a page flag.
    expect(cubit.state.operation, AuthSessionOperation.signOut);
    expect(tester.widget<OutlinedButton>(signOutButton).onPressed, isNull);

    await tester.tap(signOutButton, warnIfMissed: false);
    await tester.pump();
    expect(repository.logoutCalls, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
  });

  testWidgets(
    'traveler shell renders the local-cleanup notice once and never the M3 copy',
    (tester) async {
      final storage = _MemoryStorage({
        AppConstants.accessTokenKey: 'access',
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'traveler',
        AppConstants.keepSignedInKey: 'true',
      });
      final cubit = await _authenticatedCubit(storage: storage);
      addTearDown(cubit.close);
      storage.permanentMutationFailures.addAll({
        AppConstants.accessTokenKey,
        AppConstants.refreshTokenKey,
        AppConstants.sessionRoleKey,
        AppConstants.keepSignedInKey,
      });

      await cubit.signOut();
      await _pumpShell(tester, cubit);

      expect(cubit.state.status, AuthSessionStatus.authenticated);
      expect(find.byType(AppAlert), findsOneWidget);
      expect(
        find.text(AuthSessionCubit.signOutLocalCleanupFailureMessage),
        findsOneWidget,
      );
      // M3 must never appear on a state where the local sign-out is unproven.
      expect(
        find.text(AuthSessionCubit.signOutRemoteFailureMessage),
        findsNothing,
      );
    },
  );

  testWidgets(
    'explore and tours keep bottom navigation, filters and no root back button',
    (tester) async {
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);
      await _pumpShell(tester, cubit);

      // Home section (index 0): Trip History button is not rendered on screen
      expect(
        find.widgetWithText(
          OutlinedButton,
          TripHistoryStringsEn.tripHistoryTitle,
        ),
        findsNothing,
      );

      // Switch to trips tab (index 1): the My trips page keeps the Trip
      // History button next to its own actions.
      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Lịch trình của tôi'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Lịch sử chuyến đi'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.explore_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(ExplorePoiPage), findsOneWidget);
      expect(find.byType(AppSlidingBottomNav), findsOneWidget);
      // Explore's Find Tours shortcut selects the same shell tab.
      await tester.tap(find.text('Tìm tour'));
      await tester.pumpAndSettle();
      expect(find.byType(TourSearchPage), findsOneWidget);
      expect(find.byType(AppSlidingBottomNav), findsOneWidget);
      expect(
        tester
            .widget<AppSlidingBottomNav>(find.byType(AppSlidingBottomNav))
            .selectedIndex,
        3,
      );
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      final tours = tester
          .element(find.byType(TourSearchPage))
          .read<TourSearchCubit>();
      await tours.applyFilters(destination: 'Đà Nẵng');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Xin chào, Traveler'), findsOneWidget);
      // Bookings returns to the retained tour-list tab, without a new route.
      await tester.tap(find.byIcon(Icons.confirmation_number_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(TourSearchPage), findsOneWidget);
      expect(
        tester.element(find.byType(TourSearchPage)).read<TourSearchCubit>(),
        same(tours),
      );
      expect(tours.state.query.destination, 'Đà Nẵng');
      expect(find.text('Traveler Đặt chỗ'), findsNothing);
      expect(find.text('Sắp tới'), findsNothing);
      expect(find.text('Hoàn thành'), findsNothing);
      expect(find.text('Đã hủy'), findsNothing);
      expect(find.text('Chưa có đặt chỗ sắp tới'), findsNothing);

      // Switch to profile tab (index 4): Trip History button is displayed
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ du khách'), findsOneWidget);
      expect(
        find.widgetWithText(
          OutlinedButton,
          TripHistoryStringsEn.tripHistoryTitle,
        ),
        findsOneWidget,
      );
    },
  );
}

final class _EmptyTourRepository implements TourSearchRepository {
  @override
  Future<PagedTourResult> searchTours(TourSearchQuery query) async =>
      PagedTourResult(
        page: query.page,
        pageSize: query.pageSize,
        totalCount: 0,
        totalPages: 0,
        items: const [],
      );
}

final class _EmptyPoiRepository implements PoiRepository {
  @override
  Future<PagedPoiResult> getPois(PoiQuery query) async => const PagedPoiResult(
    page: 1,
    pageSize: 20,
    totalCount: 0,
    totalPages: 0,
    items: [],
  );

  @override
  Future<PoiDetail> getPoiDetail(int id) => throw UnimplementedError();
}

final class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.logoutCompleter});

  final Completer<void>? logoutCompleter;
  var logoutCalls = 0;

  @override
  Future<void> logout(String? refreshToken) async {
    logoutCalls += 1;
    if (logoutCompleter != null) {
      await logoutCompleter!.future;
    }
  }

  @override
  Future<AuthSession> googleAuth(String firebaseIdToken) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> login(
    AuthCredentials credentials, [
    String? firebaseIdToken,
  ]) => throw UnimplementedError();

  @override
  Future<TravelerRegistrationResult> registerTraveler(
    TravelerRegistration registration,
    String firebaseIdToken,
  ) => throw UnimplementedError();

  @override
  Future<AuthSession> verifyEmail(String firebaseIdToken) =>
      throw UnimplementedError();
}

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this.values);

  final Map<String, String> values;

  /// Keys whose mutation (delete or write) throws, to exercise the M7
  /// local-cleanup-failure branch deterministically.
  final permanentMutationFailures = <String>{};

  @override
  Future<void> delete(String key) async {
    if (permanentMutationFailures.contains(key)) {
      throw StateError('delete failed');
    }
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (permanentMutationFailures.contains(key)) {
      throw StateError('write failed');
    }
    values[key] = value;
  }
}

final class _NoticeRepository implements TravelerEmergencyRepository {
  @override
  Future<List<TravelerEmergencyNotice>> getNotices() async => [
    TravelerEmergencyNotice(
      bookingId: 42,
      scheduleId: 7,
      action: EmergencyAction.emergencyStop,
      committedAtUtc: DateTime.utc(2026, 11, 3),
      acknowledgedAtUtc: null,
    ),
  ];

  @override
  Future<TravelerEmergencyStatus> getStatus(int bookingId) =>
      throw UnimplementedError();

  @override
  Future<DateTime> acknowledge(int bookingId) => throw UnimplementedError();
}

InAppNotification _unreadNotice(int id) => InAppNotification(
  id: id,
  type: 'TravelGroupMemberRemoved',
  title: 'Removed from travel group',
  body: 'You were removed from Đà Nẵng - Hội An 3N2Đ.',
  relatedEntityType: 'TravelGroup',
  relatedEntityId: 40002,
  createdAtUtc: DateTime.utc(2026, 11, 28, 7),
  isRead: false,
);

final class _FakeUnreadInboxRepository implements InAppNotificationRepository {
  _FakeUnreadInboxRepository({
    required this.items,
    this.nextBeforeId,
  });

  List<InAppNotification> items;
  int? nextBeforeId;

  @override
  Future<InAppNotificationPage> getInbox({
    bool unreadOnly = false,
    int limit = 20,
    int? beforeId,
  }) async {
    expect(unreadOnly, isTrue);
    return InAppNotificationPage(items: items, nextBeforeId: nextBeforeId);
  }

  @override
  Future<void> markRead(int notificationId) async {}
}

final class _FakeNotificationRealtime implements InAppNotificationRealtime {
  final StreamController<void> _controller = StreamController<void>.broadcast();
  var startCalls = 0;
  var stopCalls = 0;
  var disposeCalls = 0;

  @override
  Stream<void> get changes => _controller.stream;

  void emitChange() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  @override
  Future<void> start() async => startCalls += 1;

  @override
  Future<void> stop() async => stopCalls += 1;

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _controller.close();
  }
}
