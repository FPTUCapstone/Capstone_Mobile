import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_preferences_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

import '../../../../helpers/responsive_harness.dart';

const _groupTitles = ['Interest tags', 'Travel style', 'Budget level'];
const _unavailableCopy = 'Options are configured by TripMate';
const _capabilityMessage =
    "Saving travel preferences isn't available in the app yet.";

/// Values from the previous local demo model, the Report 3 examples and the
/// Stitch mock. None of them may be shown as production option data: option
/// sets are configuration-owned and the Backend does not supply them yet.
const _noFixtureValues = [
  // previous demo model
  'Beach', 'Heritage', 'Museum', 'Local food', 'Nature', 'Nightlife',
  'Motorbike', 'Car', 'Walking', 'Public bus',
  'Relaxed', 'Balanced', 'Packed',
  'No restriction', 'Vegetarian', 'Halal', 'No seafood',
  'Low', 'Medium', 'High',
  // Report 3 examples (design examples, not authoritative data)
  'Culture', 'Food', 'Adventure', 'Relaxation', 'Shopping',
  'Solo', 'Couple', 'Family', 'Group',
  'Economy', 'Standard', 'Premium',
];

const _obsoleteModelTitles = [
  'Preferred transport',
  'Travel pace',
  'Food preference',
  'Risk tolerance',
  'Apply preferences',
  'Reset to default',
];

Widget _page({double textScale = 1.0}) =>
    harnessApp(home: const TravelPreferencesPage(), textScale: textScale);

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
    'TravelPreferencesPage (UC-09 / Screen #46) production truthfulness',
    () {
      testWidgets('renders the three canonical Report 3 preference groups', (
        tester,
      ) async {
        await pumpAtViewport(tester, _page());

        for (final title in _groupTitles) {
          await scrollIntoView(tester, find.text(title));
          expect(find.text(title), findsOneWidget, reason: title);
        }
        expect(find.text('Select any that apply'), findsOneWidget);
        expect(find.text('Select one'), findsNWidgets(2));
      });

      testWidgets('every group is truthfully unavailable', (tester) async {
        await pumpAtViewport(tester, _page());
        // The reason is stated once, above the groups.
        expect(find.textContaining(_unavailableCopy), findsOneWidget);

        for (final title in _groupTitles) {
          await scrollIntoView(tester, find.text(title));
        }
        // Each group is flagged; the explanation is stated once, not per card.
        expect(find.text('Options unavailable'), findsNWidgets(3));
      });

      testWidgets('shows no fixture option values in production', (
        tester,
      ) async {
        await pumpAtViewport(tester, _page());
        await scrollIntoView(tester, find.text('Save preferences'));

        for (final value in _noFixtureValues) {
          expect(find.text(value), findsNothing, reason: value);
        }
      });

      testWidgets(
        'has no selectable control and therefore no default selection',
        (tester) async {
          await pumpAtViewport(tester, _page());
          await scrollIntoView(tester, find.text('Save preferences'));

          expect(find.byType(FilterChip), findsNothing);
          expect(find.byType(ChoiceChip), findsNothing);
          expect(find.byType(InputChip), findsNothing);
          expect(find.byType(SegmentedButton), findsNothing);
          expect(find.byType(Switch), findsNothing);
          expect(find.byType(SwitchListTile), findsNothing);
          expect(find.byType(Checkbox), findsNothing);
          expect(find.byType(Radio), findsNothing);
          expect(find.byType(Slider), findsNothing);
        },
      );

      testWidgets(
        'no longer exposes the obsolete transport/pace/food/risk model',
        (tester) async {
          await pumpAtViewport(tester, _page());

          for (final title in _obsoleteModelTitles) {
            expect(find.textContaining(title), findsNothing, reason: title);
          }
        },
      );

      testWidgets('never claims a save, a local save or demo data', (
        tester,
      ) async {
        await pumpAtViewport(tester, _page());

        for (final forbidden in [
          'saved locally',
          'Saved',
          'demo',
          'Demo',
          'simulated',
          'preferences have been saved',
        ]) {
          expect(
            find.textContaining(forbidden),
            findsNothing,
            reason: forbidden,
          );
        }
      });

      testWidgets(
        'Save is unavailable and explains why before any interaction',
        (tester) async {
          await pumpAtViewport(tester, _page());

          expect(find.textContaining(_capabilityMessage), findsOneWidget);
          await scrollIntoView(tester, find.text('Save preferences'));
          final save = tester.widget<AppButton>(
            find.widgetWithText(AppButton, 'Save preferences'),
          );
          expect(save.onPressed, isNull);
        },
      );

      testWidgets('interacting never produces a success, spinner or request', (
        tester,
      ) async {
        await pumpAtViewport(tester, _page());
        await scrollIntoView(tester, find.text('Save preferences'));

        await tester.tap(find.text('Save preferences'), warnIfMissed: false);
        await tester.pump(const Duration(seconds: 2));

        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(http.clientsCreated, 0);
      });

      testWidgets('Skip leaves the screen without a dialog or a save', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          harnessApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TravelPreferencesPage(),
                      ),
                    ),
                    child: const Text('Open preferences'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open preferences'));
        await tester.pumpAndSettle();
        await scrollIntoView(tester, find.text('Skip'));

        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(find.text('Open preferences'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(http.clientsCreated, 0);
      });
    },
  );

  group('TravelPreferencesPage responsive and accessibility', () {
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

      await scrollIntoView(tester, find.text('Save preferences'));
      await scrollIntoView(tester, find.text('Skip'));
      expectNoFlutterException(tester);
      await expectAccessibleTapTargets(tester);
    });

    testWidgets('keyboard insets do not break the layout', (tester) async {
      await pumpAtViewport(
        tester,
        _page(),
        viewInsets: const EdgeInsets.only(bottom: 336),
        safeArea: const EdgeInsets.only(top: 48, bottom: 34),
      );

      expectNoFlutterException(tester);
      await scrollIntoView(tester, find.text('Skip'));
      expectNoFlutterException(tester);
    });

    testWidgets('long explanatory copy does not overflow at 360 and x2', (
      tester,
    ) async {
      await pumpAtViewport(
        tester,
        _page(textScale: 2.0),
        size: const Size(360, 800),
      );
      for (final title in _groupTitles) {
        await scrollIntoView(tester, find.text(title));
      }

      expectNoFlutterException(tester);
    });

    testWidgets('unavailable state is conveyed by icon and text', (
      tester,
    ) async {
      await pumpAtViewport(tester, _page());

      expect(find.byIcon(Icons.info_outline), findsWidgets);
      expect(find.textContaining(_capabilityMessage), findsOneWidget);
    });
  });
}
