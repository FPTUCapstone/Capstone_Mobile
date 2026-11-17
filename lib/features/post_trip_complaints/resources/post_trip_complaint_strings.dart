import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/validation/post_trip_complaint_validation.dart';

abstract final class PostTripComplaintStrings {
  static String categoryLabel(PostTripComplaintReasonCategory category) =>
      switch (category) {
        PostTripComplaintReasonCategory.itineraryNotAsAdvertised =>
          'Itinerary not as advertised',
        PostTripComplaintReasonCategory.serviceQuality => 'Service quality',
        PostTripComplaintReasonCategory.guideOrStaffConduct =>
          'Guide or staff conduct',
        PostTripComplaintReasonCategory.safetyIssue => 'Safety issue',
        PostTripComplaintReasonCategory.scheduleChangeOrDelay =>
          'Schedule change or delay',
        PostTripComplaintReasonCategory.other => 'Other',
      };
  static String validationMessage(PostTripComplaintValidationMessage issue) =>
      switch (issue) {
        PostTripComplaintValidationMessage.requiredDetail => detailRequired,
        PostTripComplaintValidationMessage.detailTooLong =>
          'Complaint details must be 2,000 characters or fewer.',
        PostTripComplaintValidationMessage.unsupportedType =>
          'Choose only JPG, PNG, WebP or PDF files.',
        PostTripComplaintValidationMessage.fileTooLarge =>
          'Each evidence file must be non-empty and no larger than 10 MB.',
        PostTripComplaintValidationMessage.tooManyFiles =>
          'You can attach up to 5 evidence files.',
        PostTripComplaintValidationMessage.totalTooLarge =>
          'Evidence files must total 30 MB or less.',
        PostTripComplaintValidationMessage.missingFileData =>
          'This file could not be read. Remove it and select it again.',
      };
  static const title = 'Submit post-trip complaint';
  static const myComplaints = 'My Complaints';
  static const submit = 'Submit complaint';
  static const amend = 'Add evidence';
  static const download = 'Download evidence';
  static const retry = 'Retry';
  static const windowClosed = 'The complaint window has closed.';
  static const existing = 'A complaint already exists for this booking.';
  static const systemError =
      'TripMate could not complete your request. Please try again.';
  static const invalidEvidence =
      'Choose JPG, PNG, WebP, or PDF evidence within the permitted limits.';
  static const tooManyEvidence = 'You can attach at most five evidence files.';
  static const evidenceTooLarge =
      'Each evidence file must be 10 MB or smaller, and all files must total 30 MB or less.';
  static const evidenceTypeInvalid =
      'Only JPG, PNG, WebP, and PDF files are supported.';
  static const evidenceDataUnavailable =
      'The selected file could not be read. Please choose it again.';
  static const downloadUnavailable =
      'Evidence could not be opened. Please try downloading it again.';
  static const detailRequired = 'Enter complaint details.';
  static const submitted = 'Your complaint was submitted.';
  static const evidenceAdded = 'Additional evidence was added successfully.';
}
