import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

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

    test('getTripById: returns item when requesting own trip', () {
      final trip = store.getTripById(travelerId: 1, tripId: 'trip-tour-003');
      expect(trip, isNotNull);
      expect(trip?.id, equals('trip-tour-003'));
      expect(trip?.travelerId, equals(1));
    });

    test('getTripById: returns null when requesting non-existent trip', () {
      final trip = store.getTripById(travelerId: 1, tripId: 'trip-invalid-xxx');
      expect(trip, isNull);
    });

    test(
      'getTripById: throws PermissionFailure when requesting foreign traveler trip',
      () {
        expect(
          () => store.getTripById(travelerId: 1, tripId: 'trip-tour-999'),
          throwsA(isA<PermissionFailure>()),
        );
      },
    );

    test(
      'P1 / UC-33: Self-planned itineraries cannot be reviewed via submitReview',
      () {
        expect(
          () => store.submitReview(
            const TripReviewSubmission(
              tripId: 'trip-itin-006',
              bookingCode: 'ITIN-2026-006',
              travelerId: 1,
              rating: 5,
              title: 'Self-planned review attempt',
              content: 'Should not be allowed to review itinerary.',
            ),
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (e) => e.message,
              'message',
              equals(TripHistoryStringsEn.noticeSelfPlannedNoReview),
            ),
          ),
        );
      },
    );

    test(
      'P1 / UC-33: Self-planned itineraries cannot be reviewed via updateReview',
      () {
        expect(
          () => store.updateReview(
            const TripReviewSubmission(
              tripId: 'trip-itin-006',
              bookingCode: 'ITIN-2026-006',
              travelerId: 1,
              rating: 5,
              title: 'Self-planned review update attempt',
              content: 'Should not be allowed to update review on itinerary.',
            ),
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (e) => e.message,
              'message',
              equals(TripHistoryStringsEn.noticeSelfPlannedNoReview),
            ),
          ),
        );
      },
    );

    test(
      'P2 / CR-07: Date range filter inclusively includes trips departing later on the end calendar day',
      () {
        // Default fixture trip-tour-003 departs 7 days before fixedNow (2026-10-01 12:00:00)
        // When user selects date range ending on 2026-10-01 at 00:00:00 (as returned by showDateRangePicker):
        final startDate = DateTime(2026, 9, 25);
        final endDateMidnight = DateTime(2026, 10, 1, 0, 0, 0);

        final trips = store.getTrips(
          travelerId: 1,
          status: TripStatus.completed,
          startDate: startDate,
          endDate: endDateMidnight,
        );

        // trip-tour-003 (Oct 1 12:00:00) and trip-tour-004 (Sep 28 12:00:00) must be included
        expect(
          trips.items.any((t) => t.id == 'trip-tour-003'),
          isTrue,
          reason:
              'Trip departing at 12:00 on the selected end date must be included',
        );
        expect(trips.items.any((t) => t.id == 'trip-tour-004'), isTrue);
      },
    );

    test(
      'P2 / CR-07: Same-day date range filter inclusively includes trips departing at any hour on that day',
      () {
        // User filters for only 2026-10-01 (same start and end date at midnight)
        final singleDay = DateTime(2026, 10, 1, 0, 0, 0);

        final trips = store.getTrips(
          travelerId: 1,
          status: TripStatus.completed,
          startDate: singleDay,
          endDate: singleDay,
        );

        expect(trips.items.length, equals(1));
        expect(trips.items.first.id, equals('trip-tour-003'));
      },
    );

    test(
      'P2 / CR-07: Trips departing on the day after the end date are excluded',
      () {
        // End date is Sep 30; trip-tour-003 departs Oct 1 -> must be excluded
        final endDate = DateTime(2026, 9, 30, 0, 0, 0);

        final trips = store.getTrips(
          travelerId: 1,
          status: TripStatus.completed,
          startDate: DateTime(2026, 9, 1),
          endDate: endDate,
        );

        expect(trips.items.any((t) => t.id == 'trip-tour-003'), isFalse);
      },
    );

    test(
      'P2 / CR-07: Cross-month and cross-year date range filters work accurately',
      () {
        // Cross-month: Sep 20 to Oct 5
        final crossMonth = store.getTrips(
          travelerId: 1,
          status: TripStatus.completed,
          startDate: DateTime(2026, 9, 20),
          endDate: DateTime(2026, 10, 5),
        );
        // Includes trip-tour-004 (Sep 28) and trip-tour-003 (Oct 1)
        expect(
          crossMonth.items.map((t) => t.id),
          containsAll(['trip-tour-003', 'trip-tour-004']),
        );

        // Cross-year: Dec 2025 to Jan 2027
        final crossYear = store.getTrips(
          travelerId: 1,
          startDate: DateTime(2025, 12, 1),
          endDate: DateTime(2027, 1, 1),
        );
        expect(crossYear.items.length, equals(9));
      },
    );

    test(
      'F-01 / CR-07: Date picker civil dates with non-zero hours or foreign timezones preserve exact calendar day',
      () {
        // Oct 1, 2026 filter with evening hour (e.g. 23:30 from a local device or picker)
        final localPickedDate = DateTime(2026, 10, 1, 23, 30, 0);

        final trips = store.getTrips(
          travelerId: 1,
          status: TripStatus.completed,
          startDate: localPickedDate,
          endDate: localPickedDate,
        );

        // Still includes trip-tour-003 which departs on Oct 1, 2026
        expect(trips.items.length, equals(1));
        expect(trips.items.first.id, equals('trip-tour-003'));

        // UTC date representing Oct 1
        final utcPickedDate = DateTime.utc(2026, 10, 1);
        final utcTrips = store.getTrips(
          travelerId: 1,
          status: TripStatus.completed,
          startDate: utcPickedDate,
          endDate: utcPickedDate,
        );
        expect(utcTrips.items.length, equals(1));
        expect(utcTrips.items.first.id, equals('trip-tour-003'));
      },
    );

    test(
      'P3: submitReview rejects photo count exceeding maximum (5) with validationPhotoMaxCount',
      () {
        const sixPhotos = [
          TripReviewPhotoAttachment(name: 'p1.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p2.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p3.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p4.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p5.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p6.jpg', sizeBytes: 1000),
        ];

        expect(
          () => store.submitReview(
            const TripReviewSubmission(
              tripId: 'trip-tour-003',
              bookingCode: 'BK-TOUR-003',
              travelerId: 1,
              rating: 5,
              title: 'Great trip with many photos',
              content: 'Everything was awesome.',
              photos: sixPhotos,
            ),
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (e) => e.message,
              'message',
              equals(TripHistoryStringsEn.validationPhotoMaxCount),
            ),
          ),
        );
      },
    );

    test('P3: submitReview allows up to 5 valid photos', () {
      const fivePhotos = [
        TripReviewPhotoAttachment(name: 'p1.jpg', sizeBytes: 1000),
        TripReviewPhotoAttachment(name: 'p2.jpg', sizeBytes: 1000),
        TripReviewPhotoAttachment(name: 'p3.jpg', sizeBytes: 1000),
        TripReviewPhotoAttachment(name: 'p4.jpg', sizeBytes: 1000),
        TripReviewPhotoAttachment(name: 'p5.jpg', sizeBytes: 1000),
      ];

      final review = store.submitReview(
        const TripReviewSubmission(
          tripId: 'trip-tour-003',
          bookingCode: 'BK-TOUR-003',
          travelerId: 1,
          rating: 5,
          title: 'Great trip with 5 photos',
          content: 'Everything was awesome.',
          photos: fivePhotos,
        ),
      );

      expect(review.photoUrls.length, equals(5));
    });

    test(
      'P3: updateReview rejects photo count exceeding maximum (5) with validationPhotoMaxCount',
      () {
        const sixPhotos = [
          TripReviewPhotoAttachment(name: 'p1.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p2.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p3.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p4.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p5.jpg', sizeBytes: 1000),
          TripReviewPhotoAttachment(name: 'p6.jpg', sizeBytes: 1000),
        ];

        expect(
          () => store.updateReview(
            const TripReviewSubmission(
              tripId: 'trip-tour-004',
              bookingCode: 'BK-TOUR-004',
              travelerId: 1,
              rating: 5,
              title: 'Updated title',
              content: 'Updated content with too many photos.',
              photos: sixPhotos,
              existingReviewId: 'rev-004',
            ),
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (e) => e.message,
              'message',
              equals(TripHistoryStringsEn.validationPhotoMaxCount),
            ),
          ),
        );
      },
    );
  });
}
