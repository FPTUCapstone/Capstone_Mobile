import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/app.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';

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

  testWidgets('sign-in screen renders on app bootstrap', (tester) async {
    await tester.pumpWidget(const TripMateApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
  });

  testWidgets('invalid sign-in shows a safe inline error', (tester) async {
    await tester.pumpWidget(const TripMateApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'traveler@tripmate.demo',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Email or password is incorrect. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('valid Traveler sign-in reaches the Traveler area', (
    tester,
  ) async {
    await tester.pumpWidget(const TripMateApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'traveler@tripmate.demo',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Traveler · Home'), findsOneWidget);
    expect(find.text('Traveler Home'), findsOneWidget);
    expect(find.text('Your next adventure starts here.'), findsOneWidget);
  });
}
