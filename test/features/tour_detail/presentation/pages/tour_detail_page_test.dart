import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_state.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/pages/tour_detail_page.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/resources/tour_detail_strings.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

Widget _buildTestWidget({
  required String tourId,
  TourSummary? initialSummary,
  bool isDemoMode = false,
  AuthSessionCubit? authCubit,
  double textScaleFactor = 1.0,
}) {
  return BlocProvider<AuthSessionCubit>.value(
    value: authCubit ?? AuthSessionCubit(),
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
        child: TourDetailPage(
          tourId: tourId,
          initialSummary: initialSummary,
          isDemoMode: isDemoMode,
        ),
      ),
    ),
  );
}

void main() {
  group('TourDetailPage', () {
    testWidgets('production mode displays pending integration truthfully', (
      tester,
    ) async {
      final summary = TourSummary(
        tourId: 'tour-prod-1',
        title: 'Tour Miền Tây 2N1Đ',
        destinations: const ['Cần Thơ', 'Bến Tre'],
        operatorName: 'Mien Tay Travel',
        durationDays: 2,
        basePrice: 1500000,
        currency: 'VND',
        representativeScheduleId: 'sch-mt-1',
        departureAtUtc: DateTime.utc(2026, 11, 1, 1, 0),
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 15,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          tourId: 'tour-prod-1',
          initialSummary: summary,
          isDemoMode: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(TourDetailStrings.appBarTitle), findsOneWidget);
      expect(
        find.text(TourDetailStrings.pendingIntegrationTitle),
        findsOneWidget,
      );
      expect(find.text('Tour Miền Tây 2N1Đ'), findsOneWidget);
      expect(find.text(TourDetailStrings.backToTourList), findsOneWidget);
    });

    testWidgets('demo mode displays complete tour details sections', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(tourId: 'demo-tour-1', isDemoMode: true),
      );
      await tester.pumpAndSettle();

      expect(find.text(TourDetailStrings.appBarTitle), findsOneWidget);
      expect(find.textContaining('Da Nang'), findsWidgets);
      expect(find.text('Central Vietnam Travel'), findsOneWidget);
      expect(find.text(TourDetailStrings.schedulesTitle), findsOneWidget);
      expect(find.text(TourDetailStrings.itineraryTitle), findsOneWidget);
      expect(find.text(TourDetailStrings.servicesTitle), findsOneWidget);
      expect(
        find.text(TourDetailStrings.cancellationPolicyTitle),
        findsOneWidget,
      );
      expect(find.text(TourDetailStrings.reviewsTitle), findsOneWidget);
      expect(find.text(TourDetailStrings.bookNow), findsOneWidget);
    });

    testWidgets(
      'selecting sold-out schedule triggers MSG65 and disables Book Now button',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(tourId: 'demo-tour-1', isDemoMode: true),
        );
        await tester.pumpAndSettle();

        // Find the sold-out departure schedule item (sch-003)
        // Scroll down to make schedule card visible
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        final soldOutCard = find.byKey(const Key('schedule-sch-003'));
        expect(soldOutCard, findsOneWidget);

        await tester.tap(soldOutCard);
        await tester.pumpAndSettle();

        // MSG65 warning appears
        expect(find.text(TourDetailState.msg65), findsOneWidget);

        // Bottom bar button becomes "Sold Out" and is disabled
        final bookNowBtn = tester.widget<FilledButton>(
          find.byKey(const Key('tour-detail-book-now-button')),
        );
        expect(bookNowBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'simulating no reviews displays MSG128 without hiding other sections',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(tourId: 'demo-tour-1', isDemoMode: true),
        );
        await tester.pumpAndSettle();

        // Tap demo chip for no reviews
        final chip = find.text(TourDetailStrings.demoChipNoReviews);
        expect(chip, findsOneWidget);
        await tester.tap(chip);
        await tester.pumpAndSettle();

        // Scroll to reviews section
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();

        expect(find.text(TourDetailState.msg128), findsOneWidget);
        expect(find.text(TourDetailStrings.itineraryTitle), findsWidgets);
        expect(find.text(TourDetailStrings.servicesTitle), findsWidgets);
      },
    );

    testWidgets('simulating error displays MSG127 with retry button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(tourId: 'demo-tour-1', isDemoMode: true),
      );
      await tester.pumpAndSettle();

      final chip = find.text(TourDetailStrings.demoChipError);
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text(TourDetailStrings.errorTitle), findsOneWidget);
      expect(find.text(TourDetailState.msg127), findsOneWidget);
      expect(find.text(TourDetailStrings.retry), findsOneWidget);
    });

    testWidgets(
      'simulating all-schedules-unavailable state displays MSG65 and disables Book Now',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(tourId: 'demo-tour-1', isDemoMode: true),
        );
        await tester.pumpAndSettle();

        final chip = find.text(TourDetailStrings.demoChipSoldOut);
        expect(chip, findsOneWidget);
        await tester.tap(chip);
        await tester.pumpAndSettle();

        expect(find.text(TourDetailState.msg65), findsOneWidget);
        final bookNowBtn = tester.widget<FilledButton>(
          find.byKey(const Key('tour-detail-book-now-button')),
        );
        expect(bookNowBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'BR-54: guest can view tour detail publicly but tapping Book Now requires authentication',
      (tester) async {
        final unauthSession = AuthSessionCubit();
        addTearDown(unauthSession.close);

        await tester.pumpWidget(
          _buildTestWidget(
            tourId: 'demo-tour-1',
            isDemoMode: true,
            authCubit: unauthSession,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(TourDetailStrings.appBarTitle), findsOneWidget);

        final bookNowBtn = find.byKey(const Key('tour-detail-book-now-button'));
        await tester.tap(bookNowBtn);
        await tester.pumpAndSettle();

        expect(find.text(TourDetailStrings.loginRequiredTitle), findsOneWidget);
        expect(find.text(TourDetailStrings.loginAction), findsOneWidget);
      },
    );

    group('Responsive and accessibility checks', () {
      final viewports = <String, Size>{
        'compact 360x640': const Size(360, 640),
        'standard 390x844': const Size(390, 844),
        'large 412x915': const Size(412, 915),
      };

      for (final entry in viewports.entries) {
        testWidgets('renders cleanly on ${entry.key}', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _buildTestWidget(tourId: 'demo-tour-1', isDemoMode: true),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text(TourDetailStrings.appBarTitle), findsOneWidget);
        });
      }

      testWidgets('renders without overflow at 200% font scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _buildTestWidget(
            tourId: 'demo-tour-1',
            isDemoMode: true,
            textScaleFactor: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(TourDetailStrings.appBarTitle), findsOneWidget);
      });
    });
  });
}
