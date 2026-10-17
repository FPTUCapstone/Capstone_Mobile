import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_shell_page.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';

import '../cubit/my_trips_cubit_test.dart';

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
      ..registerFactory<PoiListCubit>(
        () => PoiListCubit(getPois: GetPoisUseCase(_EmptyPoiRepository())),
      )
      ..registerFactory<MyTripsCubit>(
        () => MyTripsCubit(repository: tripRepository),
      );
  });

  tearDown(serviceLocator.reset);

  testWidgets('trips tab lists the traveler itineraries on each visit', (
    tester,
  ) async {
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.text('Chuyến đi'));
    await tester.pumpAndSettle();

    expect(find.text('Trip 60014'), findsOneWidget);
    expect(find.text('Trip in progress'), findsOneWidget);
    expect(find.text('Feature placeholder'), findsNothing);

    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyến đi'));
    await tester.pumpAndSettle();
    expect(tripRepository.requestedPages, [1, 1]);
  });

  testWidgets('traveler shell sign-out uses the backend-integrated flow once', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.logout));
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    // The existing one-tap UX stays unchanged: no confirmation step.
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('traveler shell sign-out action is disabled while in flight', (
    tester,
  ) async {
    final completer = Completer<void>();
    final repository = _RecordingAuthRepository(logoutCompleter: completer);
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.logout));
    await tester.pump();

    // Busy state is derived from the approved Cubit marker, not a page flag.
    expect(cubit.state.operation, AuthSessionOperation.signOut);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.logout))
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.logout),
      warnIfMissed: false,
    );
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
    'F-05: shell routes to sections and renders Trip History button in trips, bookings, and profile sections',
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
      expect(find.text('My trips'), findsOneWidget);
      expect(
        find.widgetWithText(
          OutlinedButton,
          TripHistoryStringsEn.tripHistoryTitle,
        ),
        findsOneWidget,
      );

      // Switch to bookings tab (index 3): Trip History button is displayed
      await tester.tap(find.byIcon(Icons.confirmation_number_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Traveler Đặt chỗ'), findsOneWidget);
      expect(
        find.widgetWithText(
          OutlinedButton,
          TripHistoryStringsEn.tripHistoryTitle,
        ),
        findsOneWidget,
      );

      // Switch to profile tab (index 4): Trip History button is displayed
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.text('Traveler Hồ sơ'), findsOneWidget);
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
