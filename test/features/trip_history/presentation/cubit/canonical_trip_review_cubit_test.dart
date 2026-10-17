import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/canonical_trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/canonical_trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/canonical_trip_review_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/canonical_trip_review_cubit.dart';

const ref = ReviewableRecordRef(
  kind: ReviewableRecordKind.commerceBooking,
  id: 7,
);

CanonicalTripReview review() => CanonicalTripReview(
  id: 2,
  rating: 5,
  title: 'Great',
  content: 'Excellent',
  publishDisplayName: true,
  createdAtUtc: DateTime.utc(2026),
  editDeadlineUtc: DateTime.utc(2026, 1, 8),
  version: 'v1',
  mediaUrls: const [],
);

CanonicalReviewContext reviewContext([CanonicalTripReview? value]) =>
    CanonicalReviewContext(
      reference: ref,
      bookingStatus: 'Completed',
      name: 'Hoi An',
      departureAtUtc: DateTime.utc(2026),
      bookingReference: 'BK-1',
      canSubmit: value == null,
      submitUnavailableReason: null,
      existingReviewKind: value == null ? 'none' : 'new',
      review: value,
      editableFields: value == null
          ? const []
          : const ['overallRating', 'title', 'content', 'publishDisplayName'],
    );

final class FakeRepository implements CanonicalTripReviewRepository {
  CanonicalReviewContext context = reviewContext();
  Failure? createFailure;
  Failure? updateFailure;
  Failure? getFailure;
  int getCalls = 0;

  @override
  Future<CanonicalReviewContext> getContext(
    ReviewableRecordRef reference,
  ) async {
    getCalls++;
    if (getFailure case final failure?) throw failure;
    return context;
  }

  @override
  Future<CanonicalTripReview> create(
    ReviewableRecordRef reference, {
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required List<ReviewPhotoUpload> photos,
  }) async {
    if (createFailure case final failure?) throw failure;
    return review();
  }

  @override
  Future<CanonicalTripReview> update(
    ReviewableRecordRef reference, {
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required String version,
  }) async {
    if (updateFailure case final failure?) throw failure;
    return review();
  }
}

void main() {
  late FakeRepository repository;
  late CanonicalTripReviewCubit cubit;

  setUp(() {
    repository = FakeRepository();
    cubit = CanonicalTripReviewCubit(
      reference: ref,
      useCase: CanonicalTripReviewUseCase(repository),
    );
  });

  tearDown(() => cubit.close());

  blocTest<CanonicalTripReviewCubit, CanonicalTripReviewState>(
    'marks a successful create for return to Trip History',
    build: () => cubit,
    act: (cubit) async {
      await cubit.load();
      await cubit.submit(
        rating: 5,
        title: 'Great',
        content: 'Excellent',
        publishDisplayName: true,
        photos: [
          ReviewPhotoUpload(
            name: 'a.png',
            contentType: 'image/png',
            bytes: Uint8List.fromList([1]),
          ),
        ],
      );
    },
    verify: (_) => expect(cubit.state.outcome, CanonicalReviewOutcome.created),
  );

  blocTest<CanonicalTripReviewCubit, CanonicalTripReviewState>(
    'updates an existing review in place',
    build: () {
      repository.context = reviewContext(review());
      return cubit;
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.submit(
        rating: 4,
        title: 'Updated',
        content: 'Updated review',
        publishDisplayName: false,
        photos: const [],
      );
    },
    verify: (_) {
      expect(cubit.state.outcome, CanonicalReviewOutcome.updated);
      expect(cubit.state.message, 'Review updated.');
    },
  );

  for (final failure in <Failure>[
    const ConflictFailure('trip_review.stale_version'),
    const ValidationFailure('trip_review.policy_rejected'),
    const ServerFailure('trip_review.policy_unavailable'),
    const NetworkFailure('internal socket details'),
  ]) {
    blocTest<CanonicalTripReviewCubit, CanonicalTripReviewState>(
      'maps ${failure.message} to safe copy without success',
      build: () {
        repository.createFailure = failure;
        return cubit;
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.submit(
          rating: 5,
          title: 'Great',
          content: 'Excellent',
          publishDisplayName: true,
          photos: const [],
        );
      },
      verify: (_) {
        expect(cubit.state.outcome, CanonicalReviewOutcome.none);
        expect(cubit.state.message, isNot(failure.message));
      },
    );
  }

  blocTest<CanonicalTripReviewCubit, CanonicalTripReviewState>(
    'recovers a duplicate by loading and exposing the existing review',
    build: () {
      repository.createFailure = const ConflictFailure('trip_review.duplicate');
      return cubit;
    },
    act: (cubit) async {
      await cubit.load();
      repository.context = reviewContext(review());
      await cubit.submit(
        rating: 5,
        title: 'Great',
        content: 'Excellent',
        publishDisplayName: true,
        photos: const [],
      );
    },
    verify: (_) {
      expect(repository.getCalls, 2);
      expect(cubit.state.context?.review, isNotNull);
      expect(cubit.state.message, contains('already exists'));
    },
  );
}
