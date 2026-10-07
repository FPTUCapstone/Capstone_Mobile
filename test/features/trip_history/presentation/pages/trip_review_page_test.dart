import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_review_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/pages/trip_review_page.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/star_rating_selector.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

void main() {
  late DateTime fixedNow;
  late DemoTripHistoryStore demoStore;
  late TripReviewRepositoryImpl repository;
  late TripReviewCubit cubit;

  setUp(() {
    fixedNow = DateTime(2026, 10, 8, 12, 0, 0);
    demoStore = DemoTripHistoryStore(now: fixedNow);
    repository = TripReviewRepositoryImpl(
      demoStore: demoStore,
      isDemoMode: true,
    );
    cubit = TripReviewCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildTestWidget(TripHistoryItem trip) {
    return MaterialApp(
      home: BlocProvider<TripReviewCubit>.value(
        value: cubit,
        child: TripReviewPage(
          trip: trip,
          travelerId: 1,
          referenceTime: fixedNow,
        ),
      ),
    );
  }

  group('TripReviewPage (Screen #74) Widget Tests', () {
    testWidgets(
      'renders summary area with tour name, departure date, and booking code',
      (tester) async {
        final trip = demoStore.getTripById(
          travelerId: 1,
          tripId: 'trip-tour-003',
        )!;

        await tester.pumpWidget(buildTestWidget(trip));
        await tester.pumpAndSettle();

        expect(find.text(TripHistoryStringsEn.tripReviewTitle), findsOneWidget);
        expect(
          find.text(TripHistoryStringsEn.summarySectionTitle),
          findsOneWidget,
        );
        expect(find.text(trip.title), findsOneWidget);
        expect(find.textContaining(trip.bookingCode), findsOneWidget);
        expect(find.byType(StarRatingSelector), findsOneWidget);
        expect(
          find.text(TripHistoryStringsEn.actionSubmitReview),
          findsOneWidget,
        );
      },
    );

    testWidgets('validation: submitting without rating displays rating error', (
      tester,
    ) async {
      final trip = demoStore.getTripById(
        travelerId: 1,
        tripId: 'trip-tour-003',
      )!;

      await tester.pumpWidget(buildTestWidget(trip));
      await tester.pumpAndSettle();

      // Enter title & content but no rating
      await tester.enterText(
        find.widgetWithText(TextField, TripHistoryStringsEn.reviewTitleHint),
        'Nice trip',
      );
      await tester.enterText(
        find.widgetWithText(TextField, TripHistoryStringsEn.reviewContentHint),
        'Very nice experience indeed.',
      );

      // Tap submit
      final submitBtn1 = find.text(TripHistoryStringsEn.actionSubmitReview);
      await tester.ensureVisible(submitBtn1);
      await tester.tap(submitBtn1);
      await tester.pumpAndSettle();

      expect(
        find.text(TripHistoryStringsEn.validationRatingRequired),
        findsOneWidget,
      );
    });

    testWidgets(
      'validation: submitting without title/content displays required field error',
      (tester) async {
        final trip = demoStore.getTripById(
          travelerId: 1,
          tripId: 'trip-tour-003',
        )!;

        await tester.pumpWidget(buildTestWidget(trip));
        await tester.pumpAndSettle();

        // Tap 5th star
        final stars = find.byIcon(Icons.star_outline_rounded);
        expect(stars, findsNWidgets(5));
        await tester.tap(stars.last);
        await tester.pumpAndSettle();

        // Submit without title/content
        final submitBtn2 = find.text(TripHistoryStringsEn.actionSubmitReview);
        await tester.ensureVisible(submitBtn2);
        await tester.tap(submitBtn2);
        await tester.pumpAndSettle();

        expect(
          find.text(TripHistoryStringsEn.validationFieldRequired),
          findsNWidgets(2), // Both title and content
        );
      },
    );

    testWidgets(
      'BR-95 / MSG67: Read-only review mode disables inputs and hides submit button',
      (tester) async {
        final trip = demoStore.getTripById(
          travelerId: 1,
          tripId: 'trip-srv-005',
        )!; // 18 days old

        await tester.pumpWidget(buildTestWidget(trip));
        await tester.pumpAndSettle();

        expect(find.text(TripHistoryStringsEn.viewReviewTitle), findsOneWidget);
        expect(
          find.text(TripHistoryStringsEn.reviewReadOnlyNotice),
          findsOneWidget,
        );

        // Submit button is NOT rendered in read-only mode
        expect(
          find.text(TripHistoryStringsEn.actionSubmitReview),
          findsNothing,
        );
        expect(find.text(TripHistoryStringsEn.actionSaveReview), findsNothing);
        // Cancel / Close is available
        expect(find.text(TripHistoryStringsEn.actionCancel), findsOneWidget);
      },
    );

    testWidgets('successful review submission displays SnackBar', (
      tester,
    ) async {
      final trip = demoStore.getTripById(
        travelerId: 1,
        tripId: 'trip-tour-003',
      )!;

      await tester.pumpWidget(buildTestWidget(trip));
      await tester.pumpAndSettle();

      // Select rating
      final stars = find.byIcon(Icons.star_outline_rounded);
      await tester.tap(stars.last);
      await tester.pumpAndSettle();

      // Enter title & content
      await tester.enterText(
        find.widgetWithText(TextField, TripHistoryStringsEn.reviewTitleHint),
        'Unforgettable evening',
      );
      await tester.enterText(
        find.widgetWithText(TextField, TripHistoryStringsEn.reviewContentHint),
        'Lanterns, river boats, and delicious food.',
      );

      // Tap submit
      final submitBtn3 = find.text(TripHistoryStringsEn.actionSubmitReview);
      await tester.ensureVisible(submitBtn3);
      await tester.tap(submitBtn3);
      await tester.pumpAndSettle();

      expect(
        find.text(TripHistoryStringsEn.reviewSubmitSuccess),
        findsOneWidget,
      );
    });

    testWidgets('responsive layout on different device widths', (tester) async {
      final trip = demoStore.getTripById(
        travelerId: 1,
        tripId: 'trip-tour-003',
      )!;
      final sizes = [
        const Size(360, 640),
        const Size(390, 844),
        const Size(412, 915),
      ];

      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestWidget(trip));
        await tester.pumpAndSettle();

        expect(find.text(TripHistoryStringsEn.tripReviewTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
