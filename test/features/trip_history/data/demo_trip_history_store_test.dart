import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';

void main() {
  late DateTime fixedNow;
  late DemoTripHistoryStore store;

  setUp(() {
    fixedNow = DateTime(2026, 10, 8, 12, 0, 0);
    store = DemoTripHistoryStore(now: fixedNow);
  });

  group('DemoTripHistoryStore BR & Functionality Tests', () {
    test(
      'BR-90: Strictly returns records for the authenticated traveler only',
      () {
        final traveler1Trips = store.getTrips(travelerId: 1);
        final traveler999Trips = store.getTrips(travelerId: 999);

        // Traveler 1 has 9 records
        expect(traveler1Trips.items.length, equals(9));
        expect(traveler1Trips.items.every((t) => t.travelerId == 1), isTrue);

        // Foreign traveler 999 has 1 record
        expect(traveler999Trips.items.length, equals(1));
        expect(traveler999Trips.items.first.bookingCode, equals('BK-TOUR-999'));
        expect(traveler999Trips.items.first.travelerId, equals(999));

        // Traveler 1 never sees BK-TOUR-999
        expect(
          traveler1Trips.items.any((t) => t.bookingCode == 'BK-TOUR-999'),
          isFalse,
        );
      },
    );

    test(
      'Tabs filtering: groups correctly by upcoming, completed, and cancelled',
      () {
        final upcoming = store.getTrips(
          travelerId: 1,
          status: TripStatus.upcoming,
        );
        final completed = store.getTrips(
          travelerId: 1,
          status: TripStatus.completed,
        );
        final cancelled = store.getTrips(
          travelerId: 1,
          status: TripStatus.cancelled,
        );

        expect(upcoming.items.length, equals(2));
        expect(
          upcoming.items.every((t) => t.status == TripStatus.upcoming),
          isTrue,
        );

        expect(completed.items.length, equals(4));
        expect(
          completed.items.every((t) => t.status == TripStatus.completed),
          isTrue,
        );

        expect(cancelled.items.length, equals(3));
        expect(
          cancelled.items.every((t) => t.status == TripStatus.cancelled),
          isTrue,
        );
      },
    );

    test(
      'Default sorting: items are sorted by departure date in descending order',
      () {
        final trips = store.getTrips(travelerId: 1);
        for (var i = 0; i < trips.items.length - 1; i++) {
          final current = trips.items[i].departureDate;
          final next = trips.items[i + 1].departureDate;
          expect(
            current.isAfter(next) || current.isAtSameMomentAs(next),
            isTrue,
            reason:
                'Item at $i ($current) should be >= item at ${i + 1} ($next)',
          );
        }
      },
    );

    test(
      'TripType filtering: correctly filters by tour, commercialService, or itinerary',
      () {
        final tours = store.getTrips(travelerId: 1, type: TripType.tour);
        final services = store.getTrips(
          travelerId: 1,
          type: TripType.commercialService,
        );
        final itineraries = store.getTrips(
          travelerId: 1,
          type: TripType.itinerary,
        );

        expect(tours.items.every((t) => t.type == TripType.tour), isTrue);
        expect(
          services.items.every((t) => t.type == TripType.commercialService),
          isTrue,
        );
        expect(
          itineraries.items.every((t) => t.type == TripType.itinerary),
          isTrue,
        );
        expect(itineraries.items.length, equals(1));
      },
    );

    test('Pagination according to CR-01 / BR-52', () {
      final page1 = store.getTrips(travelerId: 1, page: 1, pageSize: 3);
      expect(page1.items.length, equals(3));
      expect(page1.totalCount, equals(9));
      expect(page1.totalPages, equals(3));
      expect(page1.hasNextPage, isTrue);
      expect(page1.hasPreviousPage, isFalse);

      final page2 = store.getTrips(travelerId: 1, page: 2, pageSize: 3);
      expect(page2.items.length, equals(3));
      expect(page2.page, equals(2));
      expect(page2.hasNextPage, isTrue);
      expect(page2.hasPreviousPage, isTrue);

      final page3 = store.getTrips(travelerId: 1, page: 3, pageSize: 3);
      expect(page3.items.length, equals(3));
      expect(page3.hasNextPage, isFalse);
      expect(page3.hasPreviousPage, isTrue);
    });

    test('BR-91: Review may be submitted only for a completed trip', () {
      expect(
        () => store.submitReview(
          const TripReviewSubmission(
            tripId: 'trip-tour-001', // Upcoming
            bookingCode: 'BK-TOUR-001',
            travelerId: 1,
            rating: 5,
            title: 'Great trip',
            content: 'Had a wonderful time.',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('BR-92: At most one review may be submitted for each booking', () {
      expect(
        () => store.submitReview(
          const TripReviewSubmission(
            tripId: 'trip-tour-004', // Already reviewed
            bookingCode: 'BK-TOUR-004',
            travelerId: 1,
            rating: 5,
            title: 'Another review',
            content: 'Trying to review again.',
          ),
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test(
      'BR-93: The rating is an integer value between 1 and 5 and is mandatory',
      () {
        expect(
          () => store.submitReview(
            const TripReviewSubmission(
              tripId: 'trip-tour-003', // Completed, unreviewed
              bookingCode: 'BK-TOUR-003',
              travelerId: 1,
              rating: 0, // Invalid rating
              title: 'Invalid rating',
              content: 'Rating is 0.',
            ),
          ),
          throwsA(isA<ValidationFailure>()),
        );

        expect(
          () => store.submitReview(
            const TripReviewSubmission(
              tripId: 'trip-tour-003',
              bookingCode: 'BK-TOUR-003',
              travelerId: 1,
              rating: 6, // Invalid rating
              title: 'Invalid rating',
              content: 'Rating is 6.',
            ),
          ),
          throwsA(isA<ValidationFailure>()),
        );
      },
    );

    test(
      'BR-94: The written content of a review is screened against content policy',
      () {
        expect(
          () => store.submitReview(
            const TripReviewSubmission(
              tripId: 'trip-tour-003',
              bookingCode: 'BK-TOUR-003',
              travelerId: 1,
              rating: 4,
              title: 'Policy violation',
              content: 'Contains profanity and inappropriate text.',
            ),
          ),
          throwsA(isA<ValidationFailure>()),
        );
      },
    );

    test('BR-16: An attached photo must not exceed 5 MB', () {
      expect(
        () => store.submitReview(
          const TripReviewSubmission(
            tripId: 'trip-tour-003',
            bookingCode: 'BK-TOUR-003',
            travelerId: 1,
            rating: 5,
            title: 'Beautiful tour',
            content: 'Photos attached.',
            photos: [
              TripReviewPhotoAttachment(
                name: 'huge_file.png',
                sizeBytes: 6 * 1024 * 1024, // 6 MB > 5 MB
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test(
      'BR-16: An attached photo must have a supported format (JPEG, PNG, WebP)',
      () {
        expect(
          () => store.submitReview(
            const TripReviewSubmission(
              tripId: 'trip-tour-003',
              bookingCode: 'BK-TOUR-003',
              travelerId: 1,
              rating: 5,
              title: 'Tour with PDF attachment',
              content: 'Invalid photo format test.',
              photos: [
                TripReviewPhotoAttachment(
                  name: 'document.pdf',
                  sizeBytes: 1024 * 1024,
                ),
              ],
            ),
          ),
          throwsA(isA<ValidationFailure>()),
        );
      },
    );

    test(
      'BR-95: A published review may be edited within 7 days; read-only afterwards',
      () {
        // rev-004 was submitted 2 days ago (< 7 days) -> can edit
        final updated = store.updateReview(
          const TripReviewSubmission(
            tripId: 'trip-tour-004',
            bookingCode: 'BK-TOUR-004',
            travelerId: 1,
            rating: 4,
            title: 'Updated title',
            content: 'Updated content within 7 days.',
            existingReviewId: 'rev-004',
          ),
        );
        expect(updated.title, equals('Updated title'));
        expect(updated.rating, equals(4));

        // rev-005 was submitted 18 days ago (> 7 days) -> update rejected
        expect(
          () => store.updateReview(
            const TripReviewSubmission(
              tripId: 'trip-srv-005',
              bookingCode: 'BK-SRV-005',
              travelerId: 1,
              rating: 5,
              title: 'Late edit',
              content: 'Trying to edit after 18 days.',
              existingReviewId: 'rev-005',
            ),
          ),
          throwsA(isA<ValidationFailure>()),
        );
      },
    );
  });
}
