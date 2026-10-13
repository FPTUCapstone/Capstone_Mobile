import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_review_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_state.dart';
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

  group('TripReviewCubit Validation & Lifecycle Tests', () {
    test('BR-90 / MSG126: TravelerId mismatch emits permissionDenied', () {
      final trip = TripHistoryItem(
        id: 'trip-999',
        bookingCode: 'BK-999',
        title: 'Other trip',
        type: TripType.tour,
        status: TripStatus.completed,
        departureDate: fixedNow.subtract(const Duration(days: 3)),
        participantsCount: 2,
        totalAmount: 1000000,
        travelerId: 999, // Owned by 999
      );

      cubit.initialize(trip: trip, travelerId: 1); // Signed in as 1

      expect(
        cubit.state.generalError,
        equals(TripHistoryStringsEn.permissionDenied),
      );
      expect(cubit.state.status, equals(TripReviewStatus.failure));
    });

    test(
      'BR-91 / MSG52: Non-completed trip emits noticeReviewNotCompleted',
      () {
        final upcomingTrip = TripHistoryItem(
          id: 'trip-001',
          bookingCode: 'BK-001',
          title: 'Upcoming trip',
          type: TripType.tour,
          status: TripStatus.upcoming,
          departureDate: fixedNow.add(const Duration(days: 3)),
          participantsCount: 2,
          totalAmount: 1000000,
          travelerId: 1,
        );

        cubit.initialize(trip: upcomingTrip, travelerId: 1);

        expect(
          cubit.state.generalError,
          equals(TripHistoryStringsEn.noticeReviewNotCompleted),
        );
        expect(cubit.state.status, equals(TripReviewStatus.failure));
      },
    );

    test(
      'BR-93 / MSG66: Missing rating triggers ratingError on submission',
      () async {
        final trip = demoStore.getTripById(
          travelerId: 1,
          tripId: 'trip-tour-003',
        )!;
        cubit.initialize(trip: trip, travelerId: 1);

        cubit.setTitle('Great Tour');
        cubit.setContent('Really enjoyed the lantern lights.');
        // Rating is NOT selected

        await cubit.submit();

        expect(
          cubit.state.ratingError,
          equals(TripHistoryStringsEn.validationRatingRequired),
        );
        expect(cubit.state.status, equals(TripReviewStatus.initial));
      },
    );

    test(
      'MSG01: Missing title and content trigger validation errors',
      () async {
        final trip = demoStore.getTripById(
          travelerId: 1,
          tripId: 'trip-tour-003',
        )!;
        cubit.initialize(trip: trip, travelerId: 1);

        cubit.setRating(5);
        // Title and content left empty

        await cubit.submit();

        expect(
          cubit.state.titleError,
          equals(TripHistoryStringsEn.validationFieldRequired),
        );
        expect(
          cubit.state.contentError,
          equals(TripHistoryStringsEn.validationFieldRequired),
        );
      },
    );

    test(
      'BR-16 / MSG19: Photo exceeding 5MB triggers validationPhotoExceedsLimit',
      () {
        final trip = demoStore.getTripById(
          travelerId: 1,
          tripId: 'trip-tour-003',
        )!;
        cubit.initialize(trip: trip, travelerId: 1);

        // Add oversized photo (6 MB)
        cubit.addPhoto(
          const TripReviewPhotoAttachment(
            name: 'large.jpg',
            sizeBytes: 6 * 1024 * 1024,
          ),
        );

        expect(
          cubit.state.photoError,
          equals(TripHistoryStringsEn.validationPhotoExceedsLimit),
        );
        expect(cubit.state.photos, isEmpty);
      },
    );

    test('Photos count limit: Cannot add more than 5 photos', () {
      final trip = demoStore.getTripById(
        travelerId: 1,
        tripId: 'trip-tour-003',
      )!;
      cubit.initialize(trip: trip, travelerId: 1);

      for (var i = 1; i <= 5; i++) {
        cubit.addPhoto(
          TripReviewPhotoAttachment(
            name: 'photo_$i.jpg',
            sizeBytes: 1024 * 1024,
          ),
        );
      }
      expect(cubit.state.photos.length, equals(5));

      // Attempt 6th photo
      cubit.addPhoto(
        const TripReviewPhotoAttachment(
          name: 'photo_6.jpg',
          sizeBytes: 1024 * 1024,
        ),
      );

      expect(
        cubit.state.photoError,
        equals(TripHistoryStringsEn.validationPhotoMaxCount),
      );
      expect(cubit.state.photos.length, equals(5));
    });

    test('BR-94 / MSG53: Content policy violation triggers error', () async {
      final trip = demoStore.getTripById(
        travelerId: 1,
        tripId: 'trip-tour-003',
      )!;
      cubit.initialize(trip: trip, travelerId: 1);

      cubit.setRating(3);
      cubit.setTitle('Bad policy test');
      cubit.setContent('This review contains profanity.');

      await cubit.submit();

      expect(
        cubit.state.generalError,
        equals(TripHistoryStringsEn.validationContentPolicyViolation),
      );
      expect(cubit.state.status, equals(TripReviewStatus.failure));
    });

    test(
      'BR-95: Existing review within 7 days initializes in editable mode',
      () {
        final trip = demoStore.getTripById(
          travelerId: 1,
          tripId: 'trip-tour-004',
        )!; // 2 days old
        cubit.initialize(trip: trip, travelerId: 1, referenceTime: fixedNow);

        expect(cubit.state.isEdit, isTrue);
        expect(cubit.state.isReadOnly, isFalse);
        expect(cubit.state.rating, equals(5));
        expect(cubit.state.title, equals('Amazing Sunrise & Rich Heritage'));
      },
    );

    test(
      'BR-95 / MSG67: Existing review after 7 days initializes in read-only mode',
      () {
        final trip = demoStore.getTripById(
          travelerId: 1,
          tripId: 'trip-srv-005',
        )!; // 18 days old
        cubit.initialize(trip: trip, travelerId: 1, referenceTime: fixedNow);

        expect(cubit.state.isReadOnly, isTrue);
        expect(
          cubit.state.readOnlyNotice,
          equals(TripHistoryStringsEn.reviewReadOnlyNotice),
        );
      },
    );

    test('Submit valid review succeeds and returns MSG50', () async {
      final trip = demoStore.getTripById(
        travelerId: 1,
        tripId: 'trip-tour-003',
      )!;
      cubit.initialize(trip: trip, travelerId: 1);

      cubit.setRating(5);
      cubit.setTitle('Enchanting Evening');
      cubit.setContent('The lantern walk by the river was magical.');

      await cubit.submit();

      expect(cubit.state.status, equals(TripReviewStatus.success));
      expect(
        cubit.state.successMessage,
        equals(TripHistoryStringsEn.reviewSubmitSuccess),
      );
    });
  });
}
