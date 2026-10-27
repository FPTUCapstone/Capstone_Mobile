import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/models/operator_bookings_json.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/pages/operator_booking_detail_page.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';

import '../../features/operator_bookings/operator_bookings_fixtures.dart';

final class _SpyRepository implements OperatorBookingsRepository {
  final List<String> requested = [];

  @override
  Future<OperatorBookingDetail> getDetail(String bookingId) async {
    requested.add(bookingId);
    return OperatorBookingsJson.detail(detailJson(id: bookingId));
  }

  @override
  Future<OperatorBookingsPage> getPage(OperatorBookingsQuery query) =>
      throw UnimplementedError();

  @override
  Future<List<OperatorBookingTourOption>> getTourOptions() =>
      throw UnimplementedError();
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

void main() {
  late _SpyRepository repository;
  late List<bool> requestedDemoFlags;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
    );
    repository = _SpyRepository();
    requestedDemoFlags = [];
    serviceLocator
      ..unregister<OperatorBookingsRepository>()
      ..registerFactoryParam<OperatorBookingsRepository, bool, void>((
        isDemo,
        _,
      ) {
        requestedDemoFlags.add(isDemo);
        return repository;
      });
  });

  tearDown(() => serviceLocator.reset());

  Future<GoRouter> pumpAt(
    WidgetTester tester,
    String location, {
    required String role,
    String? applicationStatus,
    bool settle = true,
  }) async {
    final session = AuthSessionCubit(
      null,
      _MemoryStorage({
        AppConstants.accessTokenKey: 'access',
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: role,
        AppConstants.keepSignedInKey: 'true',
        'session_application_status': ?applicationStatus,
      }),
    );
    await session.restoreSession();
    final router = createAppRouter(session);
    addTearDown(router.dispose);
    addTearDown(session.close);
    router.go(location);
    await tester.pumpWidget(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // The application status view animates a loader, so it never settles.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 300));
    }
    return router;
  }

  String path(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  test('the route and its path helper are the operator booking page', () {
    expect(AppRoutes.operatorBooking, '/operator/bookings/:bookingId');
    expect(AppRoutes.operatorBookingPath('1201'), '/operator/bookings/1201');
    expect(
      AppRoutes.operatorBookingPath('1201', isDemo: true),
      '/operator/bookings/1201?demo=true',
    );
  });

  testWidgets(
    'an approved operator opens the booking and the detail is requested for that id',
    (tester) async {
      await pumpAt(
        tester,
        '/operator/bookings/1201',
        role: 'tourOperator',
        applicationStatus: 'approved',
      );

      expect(find.byType(OperatorBookingDetailPage), findsOneWidget);
      expect(repository.requested, ['1201']);
      expect(
        find.text(OperatorBookingsStringsEn.detailManifest),
        findsOneWidget,
      );
      expect(requestedDemoFlags, everyElement(isFalse));
    },
  );

  testWidgets('?demo=true asks for the demo repository (debug builds)', (
    tester,
  ) async {
    await pumpAt(
      tester,
      '/operator/bookings/1201?demo=true',
      role: 'tourOperator',
      applicationStatus: 'approved',
    );

    expect(find.byType(OperatorBookingDetailPage), findsOneWidget);
    expect(requestedDemoFlags, contains(true));
  });

  testWidgets(
    'a non-numeric id is answered as not found without asking the repository',
    (tester) async {
      await pumpAt(
        tester,
        '/operator/bookings/abc',
        role: 'tourOperator',
        applicationStatus: 'approved',
      );

      expect(find.byType(OperatorBookingDetailPage), findsNothing);
      expect(find.text('Page not found'), findsOneWidget);
      expect(repository.requested, isEmpty);
    },
  );

  testWidgets('a Traveler never reaches an operator booking', (tester) async {
    final router = await pumpAt(
      tester,
      '/operator/bookings/1201',
      role: 'traveler',
    );

    expect(find.byType(OperatorBookingDetailPage), findsNothing);
    expect(path(router), startsWith('/traveler'));
    expect(repository.requested, isEmpty);
  });

  for (final status in ['pendingApproval', 'rejected', 'unknown']) {
    testWidgets(
      'an operator whose application is $status is confined to the application view',
      (tester) async {
        final router = await pumpAt(
          tester,
          '/operator/bookings/1201',
          role: 'tourOperator',
          applicationStatus: status,
          settle: false,
        );

        expect(find.byType(OperatorBookingDetailPage), findsNothing);
        expect(path(router), startsWith('/operator/application'));
        expect(repository.requested, isEmpty);
      },
    );
  }

  testWidgets('an unauthenticated visitor is sent to sign in', (tester) async {
    final session = AuthSessionCubit(null, _MemoryStorage({}));
    await session.restoreSession();
    final router = createAppRouter(session);
    addTearDown(router.dispose);
    addTearDown(session.close);
    router.go('/operator/bookings/1201');
    await tester.pumpWidget(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OperatorBookingDetailPage), findsNothing);
    expect(path(router), AppRoutes.login);
    expect(repository.requested, isEmpty);
  });
}
