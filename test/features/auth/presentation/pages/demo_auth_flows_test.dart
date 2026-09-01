import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/password_demo_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_application_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/reset_password_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/traveler_registration_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_preferences_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_settings_page.dart';

void main() {
  testWidgets('Traveler registration reports required-field validation', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const TravelerRegistrationPage()));

    await _tapVisible(tester, find.byType(Checkbox));
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(find.text('Full name is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Phone number is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('password reset accepts the demo code and returns to sign-in', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/reset-test',
      routes: [
        GoRoute(
          path: '/reset-test',
          builder: (_, _) => BlocProvider(
            create: (_) => PasswordDemoCubit(),
            child: const ResetPasswordPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text('Sign-in destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerPage(router));

    await tester.enterText(find.byType(TextFormField).at(0), '123456');
    await tester.enterText(find.byType(TextFormField).at(1), 'StrongPass1!');
    await tester.enterText(find.byType(TextFormField).at(2), 'StrongPass1!');
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Set new password'),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in destination'), findsOneWidget);
  });

  testWidgets('sign out asks for confirmation before clearing the session', (
    tester,
  ) async {
    final session = AuthSessionCubit()..previewAs(UserRole.traveler);
    addTearDown(session.close);
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
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Resubmit application'),
    );
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();

    expect(cubit.state.status, OperatorApplicationStatus.pending);
  });
}

Widget _page(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

Widget _routerPage(GoRouter router) =>
    MaterialApp.router(theme: AppTheme.light, routerConfig: router);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(finder);
}
