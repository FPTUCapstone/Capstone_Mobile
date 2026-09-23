import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_application_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/traveler_registration_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_preferences_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_settings_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

const _remoteFailureCopy = AuthSessionCubit.signOutRemoteFailureMessage;
const _rawTransportDetail = 'raw transport detail';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
    );
  });

  tearDown(() => serviceLocator.reset());

  testWidgets('Traveler registration reports required-field validation', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const TravelerRegistrationPage()));

    await _tapVisible(tester, find.byType(Checkbox));
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(find.text('Full name is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('sign out asks for confirmation before clearing the session', (
    tester,
  ) async {
    final session = AuthSessionCubit(
      null,
      _MemoryStorage({
        AppConstants.accessTokenKey: 'access',
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'traveler',
        AppConstants.keepSignedInKey: 'true',
      }),
    );
    addTearDown(session.close);
    await session.restoreSession();
    await tester.pumpWidget(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: _page(const TravelerSettingsPage()),
      ),
    );

    await _tapVisible(tester, find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out of TripMate?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(session.state.isAuthenticated, isTrue);
  });

  testWidgets('Travel preferences controls update local Cubit state', (
    tester,
  ) async {
    final cubit = TravelPreferencesCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider<TravelPreferencesCubit>.value(
        value: cubit,
        child: _page(const TravelPreferencesPage()),
      ),
    );

    await _tapVisible(tester, find.text('Car'));
    await tester.pump();

    expect(cubit.state.transport, PreferredTransport.car);
  });

  testWidgets('rejected Operator resubmission reaches Pending Approval', (
    tester,
  ) async {
    final cubit = OperatorApplicationCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider<OperatorApplicationCubit>.value(
        value: cubit,
        child: _page(const OperatorApplicationPage()),
      ),
    );

    await tester.pump();
    expect(cubit.state.status, OperatorApplicationStatus.rejected);

    // Enter a valid phone number to pass validation.
    final phoneField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Business phone',
      ),
      matching: find.byType(TextFormField),
    );
    expect(phoneField, findsOneWidget);
    await tester.enterText(phoneField, '0912345678');
    await tester.pump();

    expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
    await tester.pump();

    final resubmitButton = find.byWidgetPredicate(
      (widget) => widget is AppButton && widget.label == 'Resubmit application',
      skipOffstage: false,
    );
    expect(resubmitButton, findsOneWidget);
    expect(tester.widget<AppButton>(resubmitButton).onPressed, isNotNull);

    await tester.scrollUntilVisible(
      resubmitButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final filledButton = find.descendant(
      of: resubmitButton,
      matching: find.byType(FilledButton),
    );
    expect(filledButton, findsOneWidget);
    expect(tester.widget<FilledButton>(filledButton).onPressed, isNotNull);

    await tester.tap(resubmitButton);
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();

    expect(cubit.state.status, OperatorApplicationStatus.pending);
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(find.text('REJECTED'), findsNothing);
    expect(find.text('PENDING APPROVAL'), findsOneWidget);
    expect(find.text('Application submitted'), findsOneWidget);
  });

  // --- UC-05 BR-13: failed backend revocation still completes local logout.

  testWidgets('network sign-out failure shows one login-screen notice', (
    tester,
  ) async {
    await _expectRemoteFailureNotice(
      tester,
      const NetworkException(_rawTransportDetail),
    );
  });

  testWidgets('HTTP 500 sign-out failure shows one safe login notice', (
    tester,
  ) async {
    await _expectRemoteFailureNotice(
      tester,
      const ServerException(_rawTransportDetail, 'MSG127', 500),
    );
  });

  testWidgets('login renders no notice for a clean unauthenticated state', (
    tester,
  ) async {
    final session = AuthSessionCubit();
    addTearDown(session.close);

    await tester.pumpWidget(
      _page(
        BlocProvider<AuthSessionCubit>.value(
          value: session,
          child: const LoginPage(),
        ),
      ),
    );

    expect(find.text(_remoteFailureCopy), findsNothing);
    expect(find.byType(AppAlert), findsNothing);
  });
}

Future<void> _expectRemoteFailureNotice(
  WidgetTester tester,
  AppException error,
) async {
  final storage = _MemoryStorage({
    AppConstants.accessTokenKey: 'access',
    AppConstants.refreshTokenKey: 'refresh',
    AppConstants.sessionRoleKey: 'traveler',
    AppConstants.keepSignedInKey: 'true',
  });
  final session = AuthSessionCubit(_FailingLogoutRepository(error), storage);
  addTearDown(session.close);
  await session.restoreSession();
  await session.signOut();

  expect(session.state.isAuthenticated, isFalse);
  expect(session.state.errorMessage, _remoteFailureCopy);
  expect(storage.values, isEmpty);

  await tester.pumpWidget(
    _page(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: const LoginPage(),
      ),
    ),
  );

  expect(find.byType(AppAlert), findsOneWidget);
  expect(find.text(_remoteFailureCopy), findsOneWidget);
  // Only the approved copy is rendered — never raw transport detail.
  expect(find.textContaining(_rawTransportDetail), findsNothing);
}

Widget _page(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(finder);
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

/// Fails only the logout call so remote-failure presentation is covered.
final class _FailingLogoutRepository implements AuthRepository {
  const _FailingLogoutRepository(this.error);

  final AppException error;

  @override
  Future<void> logout(String? refreshToken) => throw error;

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
