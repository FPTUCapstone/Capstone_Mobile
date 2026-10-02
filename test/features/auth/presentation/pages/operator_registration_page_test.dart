import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_registration_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

import '../../../../helpers/responsive_harness.dart';

const _fieldLabels = [
  'Email address',
  'Password',
  'Confirm password',
  'Company name',
  'Business licence number',
  'Tax code',
  'Business address',
  'Contact person',
  'Contact phone number',
];

const _capabilityMessage =
    'Operator application submission is not available in the mobile app yet.';

Widget _page({double textScale = 1.0}) =>
    harnessApp(home: const OperatorRegistrationPage(), textScale: textScale);

Future<void> _fill(WidgetTester tester, String label, String value) async {
  // Each field sits under its visible label and carries a stable key.
  final target = find.byKey(ValueKey('operator-field:$label'));
  await scrollIntoView(tester, target);
  await tester.enterText(target, value);
  await tester.pump();
}

final class _RecordingHttpOverrides extends HttpOverrides {
  var clientsCreated = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clientsCreated += 1;
    return super.createHttpClient(context);
  }
}

void main() {
  late _RecordingHttpOverrides http;

  setUp(() {
    http = _RecordingHttpOverrides();
    HttpOverrides.global = http;
  });
  tearDown(() => HttpOverrides.global = null);

  group(
    'OperatorRegistrationPage (UC-02 / Screen #40) production truthfulness',
    () {
      testWidgets('renders every canonical Report 3 form field', (
        tester,
      ) async {
        await pumpAtViewport(tester, _page());

        for (final label in _fieldLabels) {
          await scrollIntoView(tester, find.text(label).first);
          expect(find.text(label), findsWidgets, reason: label);
        }
      });

      testWidgets('renders the legal acknowledgement, unchecked by default', (
        tester,
      ) async {
        await pumpAtViewport(tester, _page());
        final checkbox = find.byType(CheckboxListTile);
        await scrollIntoView(tester, checkbox);

        expect(checkbox, findsOneWidget);
        expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
        expect(find.textContaining('Terms of Service'), findsOneWidget);
        expect(find.textContaining('Privacy Policy'), findsOneWidget);
        expect(find.textContaining('Partner Agreement'), findsOneWidget);
      });

      testWidgets(
        'document area is unavailable: no picker, no uploaded state',
        (tester) async {
          await pumpAtViewport(tester, _page());
          await scrollIntoView(tester, find.text('Business licence document'));

          expect(find.text('Business licence document'), findsOneWidget);
          expect(find.text('Supporting documents'), findsOneWidget);
          expect(find.text('UNAVAILABLE'), findsNWidgets(2));
          expect(
            find.text("Document upload isn't available in the app yet."),
            findsNWidgets(2),
          );
          for (final forbidden in [
            'Uploaded',
            'UPLOADED',
            'Mock',
            'mock',
            'demo',
            'Demo',
            'Tap to select',
            '.pdf',
            'MB',
          ]) {
            expect(
              find.textContaining(forbidden),
              findsNothing,
              reason: forbidden,
            );
          }
        },
      );

      testWidgets(
        'submission is unavailable and says why before any interaction',
        (tester) async {
          await pumpAtViewport(tester, _page());

          // The reason is visible at first render, before anything is touched.
          expect(find.textContaining(_capabilityMessage), findsOneWidget);

          await scrollIntoView(tester, find.text('Submit application'));
          final submit = tester.widget<AppButton>(
            find.widgetWithText(AppButton, 'Submit application'),
          );
          expect(submit.onPressed, isNull);
          // The reason is stated once, next to the disabled action.
          expect(
            find.textContaining('not available in the mobile'),
            findsOneWidget,
          );
        },
      );

      testWidgets('a fully valid form still never fakes a submission', (
        tester,
      ) async {
        await pumpAtViewport(tester, _page());
        final values = {
          'Email address': 'operator@example.com',
          'Password': 'Password123!',
          'Confirm password': 'Password123!',
          'Company name': 'Han River Travel',
          'Business licence number': '01-1234/2023',
          'Tax code': '0101234567',
          'Business address': '12 Pho Co, Hoan Kiem, Ha Noi',
          'Contact person': 'Nguyen Van Nam',
          'Contact phone number': '0901234567',
        };
        for (final entry in values.entries) {
          await _fill(tester, entry.key, entry.value);
        }
        await scrollIntoView(tester, find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await scrollIntoView(tester, find.text('Submit application'));
        await tester.tap(find.text('Submit application'), warnIfMissed: false);
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('Business Account'), findsOneWidget);
        for (final forbidden in [
          'Application submitted',
          'Pending Approval',
          'PENDING APPROVAL',
          'Pending Review',
          'PENDING REVIEW',
          'simulated',
        ]) {
          expect(
            find.textContaining(forbidden),
            findsNothing,
            reason: forbidden,
          );
        }
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(http.clientsCreated, 0);
      });

      testWidgets(
        'validates entered values inline without submitting anywhere',
        (tester) async {
          await pumpAtViewport(tester, _page());

          await _fill(tester, 'Email address', 'not-an-email');
          expect(find.text('Enter a valid email address.'), findsOneWidget);

          await _fill(tester, 'Company name', 'x');
          await _fill(tester, 'Company name', '');
          expect(find.text('Company name is required.'), findsOneWidget);

          await _fill(tester, 'Password', 'Password123!');
          await _fill(tester, 'Confirm password', 'Different123!');
          expect(
            find.text('Passwords do not match. Please re-enter.'),
            findsOneWidget,
          );

          await _fill(tester, 'Contact phone number', '12345');
          expect(
            find.text('Phone number must be 10 digits starting with 0.'),
            findsOneWidget,
          );
          expect(http.clientsCreated, 0);
        },
      );

      testWidgets('the contact phone number is required', (tester) async {
        await pumpAtViewport(tester, _page());

        await _fill(tester, 'Contact phone number', 'x');
        await _fill(tester, 'Contact phone number', '');

        expect(find.text('Contact phone number is required.'), findsOneWidget);
      });
    },
  );

  group('OperatorRegistrationPage navigation', () {
    Future<GoRouter> pumpWithRouter(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.operatorRegistration,
        routes: [
          GoRoute(
            path: AppRoutes.operatorRegistration,
            builder: (_, _) => const OperatorRegistrationPage(),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const Text('Sign In screen'),
          ),
          GoRoute(
            path: AppRoutes.travelerRegistration,
            builder: (_, _) => const Text('Traveler registration screen'),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('Back to Sign In returns to the sign-in screen', (
      tester,
    ) async {
      await pumpWithRouter(tester);
      await scrollIntoView(tester, find.text('Back to Sign In'));

      await tester.tap(find.text('Back to Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Sign In screen'), findsOneWidget);
    });

    testWidgets('the traveler registration link still works', (tester) async {
      await pumpWithRouter(tester);
      await scrollIntoView(
        tester,
        find.text('Create traveler account instead'),
      );

      await tester.tap(find.text('Create traveler account instead'));
      await tester.pumpAndSettle();

      expect(find.text('Traveler registration screen'), findsOneWidget);
    });
  });

  group('OperatorRegistrationPage responsive and accessibility', () {
    forEachViewportAndScale('no overflow and bottom actions reachable', (
      tester,
      viewport,
      textScale,
    ) async {
      await pumpAtViewport(
        tester,
        _page(textScale: textScale),
        size: viewport.size,
        safeArea: const EdgeInsets.only(top: 48, bottom: 34),
      );
      expectNoFlutterException(tester);

      await scrollIntoView(tester, find.text('Submit application'));
      await scrollIntoView(tester, find.text('Back to Sign In'));
      expectNoFlutterException(tester);
      await expectAccessibleTapTargets(tester);
    });

    testWidgets('keyboard open keeps a focused field usable', (tester) async {
      await pumpAtViewport(
        tester,
        _page(),
        viewInsets: const EdgeInsets.only(bottom: 336),
        safeArea: const EdgeInsets.only(top: 48, bottom: 34),
      );

      await _fill(tester, 'Contact person', 'Nguyen Van Nam');
      expectNoFlutterException(tester);
      expect(find.text('Nguyen Van Nam'), findsOneWidget);
    });

    testWidgets('a very long company name does not overflow at 360 and x2', (
      tester,
    ) async {
      await pumpAtViewport(
        tester,
        _page(textScale: 2.0),
        size: const Size(360, 800),
      );

      await _fill(
        tester,
        'Company name',
        List.filled(12, 'Han River Travel and Tourism Services').join(' '),
      );
      await _fill(
        tester,
        'Business address',
        List.filled(8, '12 Pho Co, Hoan Kiem, Ha Noi, Viet Nam').join(' '),
      );

      expectNoFlutterException(tester);
    });

    testWidgets('long validation errors stay readable at 360 and x2', (
      tester,
    ) async {
      await pumpAtViewport(
        tester,
        _page(textScale: 2.0),
        size: const Size(360, 800),
      );

      await _fill(tester, 'Password', 'short');
      expect(
        find.text('Password must be between 8 and 72 characters.'),
        findsOneWidget,
      );
      expectNoFlutterException(tester);
    });

    testWidgets('the unavailable state is communicated with icon and text', (
      tester,
    ) async {
      await pumpAtViewport(tester, _page());

      expect(find.byIcon(Icons.info_outline), findsWidgets);
      expect(find.textContaining(_capabilityMessage), findsOneWidget);
    });
  });
}
