import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_profile_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

import '../../../../helpers/responsive_harness.dart';

Future<AuthSessionCubit> _identified() => buildSessionCubit(
  fullName: 'Identified Traveler',
  email: 'identified@example.com',
);

Future<AuthSessionCubit> _noIdentity() => buildSessionCubit();

Widget _page(AuthSessionCubit session, {double textScale = 1.0}) => harnessApp(
  home: const TravelerProfilePage(),
  session: session,
  textScale: textScale,
);

void main() {
  group('TravelerProfilePage (UC-08 / Screen #45) production truthfulness', () {
    testWidgets('shows the Backend-issued full name and email', (tester) async {
      await pumpAtViewport(tester, _page(await _identified()));

      expect(find.text('Identified Traveler'), findsWidgets);
      expect(find.text('identified@example.com'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
    });

    testWidgets('email is read-only and the profile is not editable', (
      tester,
    ) async {
      await pumpAtViewport(tester, _page(await _identified()));
      await scrollIntoView(tester, find.text('Gender'));

      // A read-only profile view: no input control exists at all.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('Read only'), findsOneWidget);
      for (final label in [
        'Full name',
        'Phone number',
        'Date of birth',
        'Gender',
        'Address',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a missing identity stays truthful and is never invented', (
      tester,
    ) async {
      await pumpAtViewport(tester, _page(await _noIdentity()));

      // The header and the full-name field both say so; nothing is invented.
      expect(find.text('Name not available'), findsNWidgets(2));
      expect(find.text('Email not available'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('never renders hard-coded or demo personal data', (
      tester,
    ) async {
      await pumpAtViewport(tester, _page(await _noIdentity()));

      for (final forbidden in [
        'Nguyen Minh Phuc',
        '0905 123 456',
        '26/09/2004',
        'Da Nang',
        'PN',
        'Demo',
        'demo',
        'Email unavailable',
        'simulated',
        'locally',
      ]) {
        expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
      }
    });

    testWidgets('has no verification badge without an authoritative source', (
      tester,
    ) async {
      await pumpAtViewport(tester, _page(await _identified()));

      for (final forbidden in [
        'Verified',
        'Verify',
        'verified',
        'verification',
      ]) {
        expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
      }
      expect(find.textContaining('bio'), findsNothing);
      expect(find.textContaining('mergency'), findsNothing);
    });

    testWidgets('unsupported fields show a truthful empty presentation', (
      tester,
    ) async {
      await pumpAtViewport(tester, _page(await _identified()));
      // The avatar has no source: a neutral placeholder, no photo.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'No profile photo available',
        ),
        findsOneWidget,
      );
      await scrollIntoView(tester, find.text('Gender'));

      // Phone, address, date of birth and gender have no source yet.
      expect(find.text('Not provided'), findsNWidgets(4));
    });

    testWidgets(
      'Save changes and Change avatar are disabled with a visible reason',
      (tester) async {
        await pumpAtViewport(tester, _page(await _identified()));
        // The reason is visible before any interaction.
        expect(
          find.textContaining(
            "Profile editing isn't available in the app yet.",
          ),
          findsOneWidget,
        );
        await scrollIntoView(tester, find.text('Change avatar'));

        final save = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Save changes'),
        );
        expect(save.onPressed, isNull);
        final avatarButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Change avatar'),
        );
        expect(avatarButton.onPressed, isNull);
      },
    );

    testWidgets(
      'interacting never produces a save success, spinner or snackbar',
      (tester) async {
        await pumpAtViewport(tester, _page(await _identified()));
        await scrollIntoView(tester, find.text('Change avatar'));

        await tester.tap(find.text('Save changes'), warnIfMissed: false);
        await tester.tap(find.text('Change avatar'), warnIfMissed: false);
        await tester.pump(const Duration(seconds: 2));

        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('saved'), findsNothing);
        expect(find.textContaining('Saved'), findsNothing);
      },
    );

    testWidgets('a different session never shows the previous identity', (
      tester,
    ) async {
      await pumpAtViewport(tester, _page(await _identified()));
      expect(find.text('identified@example.com'), findsOneWidget);

      await tester.pumpWidget(
        _page(
          await buildSessionCubit(
            fullName: 'Other Traveler',
            email: 'other@example.com',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('other@example.com'), findsOneWidget);
      expect(find.textContaining('Identified'), findsNothing);
      expect(find.textContaining('identified@'), findsNothing);
    });

    testWidgets('follows a later session change in the same tree', (
      tester,
    ) async {
      final session = await _identified();
      await pumpAtViewport(
        tester,
        harnessApp(home: const TravelerProfilePage(), session: session),
      );
      expect(find.text('identified@example.com'), findsOneWidget);

      await session.handleSessionExpired();
      await tester.pump();

      expect(find.text('identified@example.com'), findsNothing);
      // Header and full-name field both fall back; no stale identity remains.
      expect(find.text('Name not available'), findsNWidgets(2));
      expect(find.text('Email not available'), findsOneWidget);
    });
  });

  group('TravelerProfilePage responsive and accessibility', () {
    forEachViewportAndScale('no overflow and bottom actions reachable', (
      tester,
      viewport,
      textScale,
    ) async {
      await pumpAtViewport(
        tester,
        _page(await _identified(), textScale: textScale),
        size: viewport.size,
        safeArea: const EdgeInsets.only(top: 48, bottom: 34),
      );
      expectNoFlutterException(tester);

      await scrollIntoView(tester, find.text('Gender'));
      expectNoFlutterException(tester);
      expect(find.text('Save changes'), findsOneWidget);
      await expectAccessibleTapTargets(tester);
    });

    testWidgets('keyboard insets do not break the layout', (tester) async {
      await pumpAtViewport(
        tester,
        _page(await _identified()),
        viewInsets: const EdgeInsets.only(bottom: 336),
        safeArea: const EdgeInsets.only(top: 48, bottom: 34),
      );
      expectNoFlutterException(tester);
      await scrollIntoView(tester, find.text('Gender'));
      expectNoFlutterException(tester);
    });

    testWidgets('very long identity values do not overflow at 360 and x2', (
      tester,
    ) async {
      final longName = List.filled(12, 'Nguyen Thi Minh Chau').join(' ');
      final longEmail =
          'very.long.email.address.with.many.segments.for.overflow.testing@'
          'subdomain.example-company-with-a-long-name.example.com';
      await pumpAtViewport(
        tester,
        _page(
          await buildSessionCubit(fullName: longName, email: longEmail),
          textScale: 2.0,
        ),
        size: const Size(360, 800),
      );

      expectNoFlutterException(tester);
      await scrollIntoView(tester, find.text('Gender'));
      expectNoFlutterException(tester);
    });

    testWidgets(
      'critical status is conveyed by icon and text, not colour only',
      (tester) async {
        await pumpAtViewport(tester, _page(await _identified()));

        expect(find.byIcon(Icons.info_outline), findsWidgets);
        expect(find.text('TRAVELER'), findsOneWidget);
        expect(find.byIcon(Icons.person_outline), findsWidgets);
      },
    );
  });
}
