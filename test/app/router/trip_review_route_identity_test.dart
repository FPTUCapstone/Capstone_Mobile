import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

void main() {
  late AuthSessionCubit session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
    );
    session = AuthSessionCubit(_TravelerAuthRepository(), _MemoryStorage());
    await session.signIn(email: 'traveler@example.com', password: 'Password1!');
  });

  tearDown(() async {
    await session.close();
    await serviceLocator.reset();
  });

  Future<void> pumpReviewRoute(
    WidgetTester tester, {
    required String pathTripId,
    Object? extra,
    bool isDemo = true,
  }) async {
    final router = createAppRouter(session);
    addTearDown(router.dispose);
    router.go(AppRoutes.tripReview(pathTripId, isDemo: isDemo), extra: extra);
    await tester.pumpWidget(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  final trip = TripHistoryItem(
    id: 'trip-tour-003',
    bookingCode: 'BK-TOUR-003',
    title: 'Completed trip',
    type: TripType.tour,
    status: TripStatus.completed,
    departureDate: DateTime(2026, 10, 1),
    participantsCount: 1,
    totalAmount: 100000,
    travelerId: 1,
  );

  testWidgets(
    'normal navigation: matching route tripId and supplied extra opens review',
    (tester) async {
      await pumpReviewRoute(
        tester,
        pathTripId: 'trip-tour-003',
        extra: trip,
        isDemo: true,
      );

      expect(
        find.text(TripHistoryStringsEn.tripInformationUnavailable),
        findsNothing,
      );
      expect(find.text(TripHistoryStringsEn.tripReviewTitle), findsOneWidget);
    },
  );

  testWidgets(
    'open detail without extra: loads trip by route ID and opens review',
    (tester) async {
      await pumpReviewRoute(
        tester,
        pathTripId: 'trip-tour-003',
        extra: null,
        isDemo: true,
      );

      expect(
        find.text(TripHistoryStringsEn.tripInformationUnavailable),
        findsNothing,
      );
      expect(find.text(TripHistoryStringsEn.tripReviewTitle), findsOneWidget);
    },
  );

  testWidgets('invalid trip id: shows trip information unavailable error', (
    tester,
  ) async {
    await pumpReviewRoute(
      tester,
      pathTripId: 'trip-invalid-xxx',
      extra: null,
      isDemo: true,
    );

    expect(
      find.text(TripHistoryStringsEn.tripInformationUnavailable),
      findsOneWidget,
    );
  });

  testWidgets(
    'unauthorized trip: foreign traveler trip fails with permission denied',
    (tester) async {
      await pumpReviewRoute(
        tester,
        pathTripId: 'trip-tour-999',
        extra: null,
        isDemo: true,
      );

      expect(find.text(TripHistoryStringsEn.permissionDenied), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.summarySectionTitle), findsNothing);
    },
  );

  testWidgets(
    'mismatched route tripId: ignores extra and validates route trip ID',
    (tester) async {
      // extra has id 'trip-tour-003', but route tripId is 'trip-tour-999' (unauthorized)
      await pumpReviewRoute(
        tester,
        pathTripId: 'trip-tour-999',
        extra: trip,
        isDemo: true,
      );

      expect(find.text(TripHistoryStringsEn.permissionDenied), findsOneWidget);
    },
  );

  testWidgets(
    'alias redirect: /traveler/trips/:tripId redirects to review pattern',
    (tester) async {
      final router = createAppRouter(session);
      addTearDown(router.dispose);
      router.go('/traveler/trips/trip-tour-003?demo=true');
      await tester.pumpWidget(
        BlocProvider<AuthSessionCubit>.value(
          value: session,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(TripHistoryStringsEn.tripReviewTitle), findsOneWidget);
    },
  );
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
