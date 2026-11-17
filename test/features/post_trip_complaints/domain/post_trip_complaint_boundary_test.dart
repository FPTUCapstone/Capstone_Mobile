import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/validation/post_trip_complaint_validation.dart';

void main() {
  const mb = 1024 * 1024;
  SelectedEvidence file(int size) => SelectedEvidence(
    name: 'proof.pdf',
    sizeBytes: size,
    contentType: 'application/pdf',
  );
  for (final length in [0, 1, 1999, 2000, 2001]) {
    test('detail boundary $length characters', () {
      final result = PostTripComplaintValidation.validateDetail('a' * length);
      expect(
        result,
        length == 0
            ? PostTripComplaintValidationMessage.requiredDetail
            : length > 2000
            ? PostTripComplaintValidationMessage.detailTooLong
            : null,
      );
    });
  }
  test('whitespace detail is empty', () {
    expect(
      PostTripComplaintValidation.validateDetail(' \n\t '),
      PostTripComplaintValidationMessage.requiredDetail,
    );
  });
  for (final count in [0, 1, 4, 5, 6]) {
    test('attachment count boundary $count', () {
      expect(
        PostTripComplaintValidation.validateEvidence(
          List.generate(count, (_) => file(1)),
        ),
        count > 5 ? PostTripComplaintValidationMessage.tooManyFiles : null,
      );
    });
  }
  for (final size in [0, 1, 10 * mb - 1, 10 * mb, 10 * mb + 1]) {
    test('per-file size boundary $size bytes', () {
      expect(
        PostTripComplaintValidation.validateEvidence([file(size)]),
        size == 0 || size > 10 * mb
            ? PostTripComplaintValidationMessage.fileTooLarge
            : null,
      );
    });
  }
  for (final total in [30 * mb - 1, 30 * mb, 30 * mb + 1]) {
    test('aggregate size boundary $total bytes', () {
      expect(
        PostTripComplaintValidation.validateEvidence([
          file(10 * mb),
          file(10 * mb),
          file(total - 20 * mb > 10 * mb ? 10 * mb : total - 20 * mb),
          if (total > 30 * mb) file(1),
        ]),
        total > 30 * mb
            ? PostTripComplaintValidationMessage.totalTooLarge
            : null,
      );
    });
  }
  test('amendment includes previously uploaded evidence in limits', () {
    expect(
      PostTripComplaintValidation.validateEvidence([file(1)], existingCount: 5),
      PostTripComplaintValidationMessage.tooManyFiles,
    );
    expect(
      PostTripComplaintValidation.validateEvidence([
        file(1),
      ], existingBytes: 30 * mb),
      PostTripComplaintValidationMessage.totalTooLarge,
    );
  });
}
