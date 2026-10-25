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
import 'package:trip_mate_mobile/features/e_ticket/domain/repositories/e_ticket_repository.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/pages/e_ticket_page.dart';
import 'package:trip_mate_mobile/features/e_ticket/resources/e_ticket_en.dart';

import '../../features/e_ticket/presentation/e_ticket_cubit_test.dart'
    show FakeETicketRepository, eTicket;

void main() {
  late AuthSessionCubit session;
  late FakeETicketRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
    );
    repository = FakeETicketRepository();
    serviceLocator
      ..unregister<ETicketRepository>()
      ..registerLazySingleton<ETicketRepository>(() => repository);
    session = AuthSessionCubit(_TravelerAuthRepository(), _MemoryStorage());
    await session.signIn(email: 'traveler@example.com', password: 'Password1!');
  });

  tearDown(() async {
    await session.close();
    await serviceLocator.reset();
  });

  Future<void> pumpAt(WidgetTester tester, String location) async {
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

  testWidgets('opens a Trip History ticket by ticket id', (tester) async {
    repository.reads.add(eTicket());

    await pumpAt(tester, AppRoutes.eTicket(77));

    expect(find.byType(ETicketPage), findsOneWidget);
    expect(repository.calls, ['ticket:77']);
  });

  testWidgets('opens the ticket of a booking by booking id', (tester) async {
    repository.reads.add(eTicket());

    await pumpAt(tester, AppRoutes.bookingETicket(456));

    expect(find.byType(ETicketPage), findsOneWidget);
    expect(repository.calls, ['booking:456']);
  });

  testWidgets('answers a malformed id with not found and no request', (
    tester,
  ) async {
    await pumpAt(tester, '/traveler/tickets/abc');

    expect(find.text(ETicketStrings.notFound), findsOneWidget);
    expect(repository.calls, isEmpty);
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
