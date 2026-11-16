import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/validation/post_trip_complaint_validation.dart';

void main() {
  test('accepts valid complaint detail and aggregate evidence limits', () {
    final outcome = PostTripComplaintValidation.validateEvidence(const [
      SelectedEvidence(
        name: 'proof.png',
        sizeBytes: 10 * 1024 * 1024,
        contentType: 'image/png',
      ),
    ]);

    expect(
      PostTripComplaintValidation.validateDetail('  Safe detail  '),
      isNull,
    );
    expect(outcome, isNull);
  });

  test('rejects unsupported, oversized and aggregate evidence', () {
    expect(
      PostTripComplaintValidation.validateEvidence(const [
        SelectedEvidence(
          name: 'proof.exe',
          sizeBytes: 1,
          contentType: 'application/octet-stream',
        ),
      ]),
      PostTripComplaintValidationMessage.unsupportedType,
    );
    expect(
      PostTripComplaintValidation.validateEvidence(const [
        SelectedEvidence(
          name: 'proof.pdf',
          sizeBytes: 10 * 1024 * 1024 + 1,
          contentType: 'application/pdf',
        ),
      ]),
      PostTripComplaintValidationMessage.fileTooLarge,
    );
    expect(
      PostTripComplaintValidation.validateEvidence(
        List.generate(
          4,
          (index) => SelectedEvidence(
            name: '$index.png',
            sizeBytes: 8 * 1024 * 1024,
            contentType: 'image/png',
          ),
        ),
      ),
      PostTripComplaintValidationMessage.totalTooLarge,
    );
  });
}
