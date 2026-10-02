import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_application_page.dart';

import '../../../../helpers/responsive_harness.dart';

Future<AuthSessionCubit> _operator(TourOperatorApplicationStatus? status) =>
    buildSessionCubit(role: UserRole.tourOperator, applicationStatus: status);

Widget _page(AuthSessionCubit session, {double textScale = 1.0}) => harnessApp(
  home: const OperatorApplicationPage(),
  session: session,
  textScale: textScale,
);

const _fabricated = [
  'Han River',
  '0401998877',
  'licence-2026',
  'licence-0401998877',
  'Replaced',
  'demo',
  'Demo',
  'simulated',
  '02 Nguyen Van Linh',
  '0236 388 1234',
  'expired',
  'CORRECT THE FOLLOWING',
  'Company address',
  'Business phone',
];

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
    'OperatorApplicationPage (UC-03 / Screen #41) production truthfulness',
    () {
      testWidgets(
        'shows the real pendingApproval status as "Pending approval"',
        (tester) async {
          await pumpAtViewport(
            tester,
            _page(
              await _operator(TourOperatorApplicationStatus.pendingApproval),
            ),
          );

          // StatusBadge renders its label upper-cased.
          expect(find.text('PENDING APPROVAL'), findsOneWidget);
          expect(find.text('PENDING REVIEW'), findsNothing);
          expect(
            find.textContaining('awaiting Administrator review'),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
        },
      );

      testWidgets(
        'pending view invents no submission, timestamp or demo copy',
        (tester) async {
          await pumpAtViewport(
            tester,
            _page(
              await _operator(TourOperatorApplicationStatus.pendingApproval),
            ),
          );

          for (final forbidden in [..._fabricated, 'submitted', 'Submitted']) {
            expect(
              find.textContaining(forbidden),
              findsNothing,
              reason: forbidden,
            );
          }
        },
      );

      testWidgets('rejected shows the real status and no invented reason', (
        tester,
      ) async {
        await pumpAtViewport(
          tester,
          _page(await _operator(TourOperatorApplicationStatus.rejected)),
        );

        expect(find.text('REJECTED'), findsOneWidget);
        expect(find.text('Rejection reason'), findsOneWidget);
        expect(find.text('Reason unavailable in the app.'), findsOneWidget);
        expect(
          find.text('Resubmission is not available in the mobile app yet.'),
          findsOneWidget,
        );
      });

      testWidgets(
        'rejected shows no fabricated company, reason or document data',
        (tester) async {
          await pumpAtViewport(
            tester,
            _page(await _operator(TourOperatorApplicationStatus.rejected)),
          );

          for (final forbidden in _fabricated) {
            expect(
              find.textContaining(forbidden),
              findsNothing,
              reason: forbidden,
            );
          }
          expect(find.textContaining('Tax code'), findsNothing);
        },
      );

      testWidgets(
        'rejected renders no blank resubmission form or resubmit action',
        (tester) async {
          await pumpAtViewport(
            tester,
            _page(await _operator(TourOperatorApplicationStatus.rejected)),
          );

          expect(find.byType(TextField), findsNothing);
          expect(find.byType(TextFormField), findsNothing);
          expect(find.byType(Form), findsNothing);
          expect(find.text('Resubmit application'), findsNothing);
          expect(find.byType(FilledButton), findsNothing);
        },
      );

      testWidgets('rejected never transitions to a pending state locally', (
        tester,
      ) async {
        final session = await _operator(TourOperatorApplicationStatus.rejected);
        await pumpAtViewport(tester, _page(session));

        await tester.tap(find.text('REJECTED'));
        await tester.tap(find.text('Reason unavailable in the app.'));
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('REJECTED'), findsOneWidget);
        expect(find.textContaining('PENDING'), findsNothing);
        expect(find.textContaining('Pending'), findsNothing);
        expect(
          session.state.applicationStatus,
          TourOperatorApplicationStatus.rejected,
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(http.clientsCreated, 0);
      });

      testWidgets('an unresolved status fails closed', (tester) async {
        await pumpAtViewport(tester, _page(await _operator(null)));

        expect(find.text('Application status unavailable'), findsOneWidget);
        expect(find.textContaining('PENDING'), findsNothing);
        expect(find.textContaining('REJECTED'), findsNothing);
        expect(find.textContaining('APPROVED'), findsNothing);
      });

      testWidgets('approved status is shown truthfully if the page is reached', (
        tester,
      ) async {
        await pumpAtViewport(
          tester,
          _page(await _operator(TourOperatorApplicationStatus.approved)),
        );

        // Routing for approved operators belongs to RouteGuards, not this page.
        expect(find.text('APPROVED'), findsOneWidget);
        expect(find.text('Resubmit application'), findsNothing);
      });

      testWidgets('reads the live session status, not a local copy', (
        tester,
      ) async {
        final session = await _operator(
          TourOperatorApplicationStatus.pendingApproval,
        );
        await pumpAtViewport(tester, _page(session));
        expect(find.text('PENDING APPROVAL'), findsOneWidget);

        await session.handleSessionExpired();
        await tester.pump();

        expect(find.text('PENDING APPROVAL'), findsNothing);
        expect(find.text('Application status unavailable'), findsOneWidget);
      });

      testWidgets('needs no operator-application cubit or Backend call', (
        tester,
      ) async {
        // Only the session provider exists in the harness; building succeeds.
        await pumpAtViewport(
          tester,
          _page(await _operator(TourOperatorApplicationStatus.rejected)),
        );

        expectNoFlutterException(tester);
        expect(http.clientsCreated, 0);
      });
    },
  );

  group('OperatorApplicationPage responsive and accessibility', () {
    for (final status in [
      TourOperatorApplicationStatus.pendingApproval,
      TourOperatorApplicationStatus.rejected,
    ]) {
      forEachViewportAndScale(
        '${status.name}: no overflow, actions reachable',
        (tester, viewport, textScale) async {
          await pumpAtViewport(
            tester,
            _page(await _operator(status), textScale: textScale),
            size: viewport.size,
            safeArea: const EdgeInsets.only(top: 48, bottom: 34),
          );

          expectNoFlutterException(tester);
          await expectAccessibleTapTargets(tester);
        },
      );
    }

    testWidgets('keyboard insets do not break the layout', (tester) async {
      await pumpAtViewport(
        tester,
        _page(await _operator(TourOperatorApplicationStatus.rejected)),
        viewInsets: const EdgeInsets.only(bottom: 336),
        safeArea: const EdgeInsets.only(top: 48, bottom: 34),
      );

      expectNoFlutterException(tester);
    });

    testWidgets('status is conveyed by icon and text, not colour only', (
      tester,
    ) async {
      await pumpAtViewport(
        tester,
        _page(await _operator(TourOperatorApplicationStatus.rejected)),
      );

      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsWidgets);
    });
  });
}
