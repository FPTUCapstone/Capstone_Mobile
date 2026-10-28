import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/demo_trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/pages/trip_history_page.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

/// Stands in for the real API: fails every call, so the screen can only show
/// an error and never a fixture.
final class _UnreachableRepository implements TripRecordsRepository {
  @override
  Future<TripRecordPage> getPage(TripRecordsQuery query) =>
      Future.error(const NetworkFailure());

  @override
  Future<TripRecordDetail> getDetail(TripRecordKind kind, int id) =>
      Future.error(const NetworkFailure());
}

void main() {
  late AuthSessionCubit session;
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
    requestedDemoFlags = [];
    serviceLocator
      ..unregister<TripRecordsRepository>()
      ..registerFactoryParam<TripRecordsRepository, bool, void>((isDemo, _) {
        requestedDemoFlags.add(isDemo);
        return isDemo
            ? const DemoTripRecordsRepository()
            : _UnreachableRepository();
      });
    session = AuthSessionCubit(_TravelerAuthRepository(), _MemoryStorage());
    await session.signIn(email: 'traveler@example.com', password: 'Password1!');
  });

  tearDown(() async {
    await session.close();
    await serviceLocator.reset();
  });

  Future<void> pumpHistory(WidgetTester tester, String location) async {
    final router = createAppRouter(session);
    addTearDown(router.dispose);
    router.go(location);
    await tester.pumpWidget(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '/traveler/trips?demo=true uses the demo records (debug builds)',
    (tester) async {
      await pumpHistory(tester, AppRoutes.tripHistoryPath(isDemo: true));

      expect(find.byType(TripHistoryPage), findsOneWidget);
      expect(requestedDemoFlags, contains(true));
      expect(find.text('Son Tra Peninsula Tour'), findsOneWidget);
    },
  );

  testWidgets('/traveler/trips reads the real API, and a failure is Retry, '
      'not fixtures or a pending banner', (tester) async {
    await pumpHistory(tester, AppRoutes.tripHistoryPath());

    expect(find.byType(TripHistoryPage), findsOneWidget);
    expect(requestedDemoFlags, everyElement(isFalse));
    expect(requestedDemoFlags, isNotEmpty);
    expect(find.text(TripHistoryStringsEn.errorMessageGeneric), findsOneWidget);
    expect(find.text(TripHistoryStringsEn.actionRetry), findsOneWidget);
    expect(find.text('Son Tra Peninsula Tour'), findsNothing);
    expect(
      find.text(TripHistoryStringsEn.productionIntegrationPending),
      findsNothing,
    );
  });
}

final class _TravelerAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login(
    AuthCredentials credentials, [
    String? firebaseIdToken,
  ]) async => const AuthSession(
    userId: 1,
    status: 'Active',
    role: 'Traveler',
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );

  @override
  Future<void> logout(String? refreshToken) async {}

  @override
  Future<AuthSession> googleAuth(String firebaseIdToken) =>
      throw UnimplementedError();

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
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
