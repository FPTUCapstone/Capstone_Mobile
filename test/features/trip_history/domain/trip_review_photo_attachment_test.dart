import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';

void main() {
  group('verified Backend photo byte boundary', () {
    test('accepts 4,999,999 and exactly 5,000,000 bytes', () {
      expect(
        const TripReviewPhotoAttachment(
          name: 'below.jpg',
          sizeBytes: 4_999_999,
        ).isValid,
        isTrue,
      );
      expect(
        const TripReviewPhotoAttachment(
          name: 'boundary.webp',
          sizeBytes: 5_000_000,
        ).isValid,
        isTrue,
      );
    });

    test('rejects 5,000,001 bytes and zero-byte files', () {
      expect(
        const TripReviewPhotoAttachment(
          name: 'over.png',
          sizeBytes: 5_000_001,
        ).isValidSize,
        isFalse,
      );
      expect(
        const TripReviewPhotoAttachment(
          name: 'empty.jpeg',
          sizeBytes: 0,
        ).isValidSize,
        isFalse,
      );
    });

    test('rejects missing or unsupported file extensions', () {
      expect(
        const TripReviewPhotoAttachment(
          name: 'missing-extension',
          sizeBytes: 100,
        ).isValidType,
        isFalse,
      );
      expect(
        const TripReviewPhotoAttachment(
          name: 'document.pdf',
          sizeBytes: 100,
        ).isValidType,
        isFalse,
      );
    });
  });
}
