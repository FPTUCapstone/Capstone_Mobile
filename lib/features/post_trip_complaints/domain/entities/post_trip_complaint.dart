import 'dart:typed_data';

import 'package:equatable/equatable.dart';

enum PostTripComplaintReasonCategory {
  itineraryNotAsAdvertised,
  serviceQuality,
  guideOrStaffConduct,
  safetyIssue,
  scheduleChangeOrDelay,
  other;

  String get wireValue => switch (this) {
    itineraryNotAsAdvertised => 'ItineraryNotAsAdvertised',
    serviceQuality => 'ServiceQuality',
    guideOrStaffConduct => 'GuideOrStaffConduct',
    safetyIssue => 'SafetyIssue',
    scheduleChangeOrDelay => 'ScheduleChangeOrDelay',
    other => 'Other',
  };

  static PostTripComplaintReasonCategory? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

final class ComplaintEvidence extends Equatable {
  const ComplaintEvidence({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });
  final int id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  @override
  List<Object?> get props => [id, fileName, contentType, sizeBytes];
}

final class ExistingPostTripComplaint extends Equatable {
  const ExistingPostTripComplaint({
    required this.id,
    required this.status,
    required this.reasonCategory,
    required this.reasonDetail,
    required this.submittedAtUtc,
    required this.responseDeadlineUtc,
    required this.evidence,
  });
  final int id;
  final String status;
  final PostTripComplaintReasonCategory reasonCategory;
  final String reasonDetail;
  final DateTime submittedAtUtc;
  final DateTime responseDeadlineUtc;
  final List<ComplaintEvidence> evidence;
  @override
  List<Object?> get props => [
    id,
    status,
    reasonCategory,
    reasonDetail,
    submittedAtUtc,
    responseDeadlineUtc,
    evidence,
  ];
}

final class PostTripComplaintContext extends Equatable {
  const PostTripComplaintContext({
    required this.bookingId,
    required this.bookingCode,
    required this.tourTitle,
    required this.endAtUtc,
    required this.submissionDeadlineUtc,
    required this.canSubmit,
    required this.canAmendEvidence,
    this.ineligibilityReason,
    this.complaint,
  });
  final int bookingId;
  final String? bookingCode;
  final String? tourTitle;
  final DateTime endAtUtc;
  final DateTime submissionDeadlineUtc;
  final bool canSubmit;
  final bool canAmendEvidence;
  final String? ineligibilityReason;
  final ExistingPostTripComplaint? complaint;
  @override
  List<Object?> get props => [
    bookingId,
    bookingCode,
    tourTitle,
    endAtUtc,
    submissionDeadlineUtc,
    canSubmit,
    canAmendEvidence,
    ineligibilityReason,
    complaint,
  ];
}

final class PostTripComplaintSubmission extends Equatable {
  const PostTripComplaintSubmission({
    required this.complaintId,
    required this.bookingId,
    required this.status,
    required this.submittedAtUtc,
    required this.responseDeadlineUtc,
    required this.isReplay,
  });
  final int complaintId;
  final int bookingId;
  final String status;
  final DateTime submittedAtUtc;
  final DateTime responseDeadlineUtc;
  final bool isReplay;
  @override
  List<Object?> get props => [
    complaintId,
    bookingId,
    status,
    submittedAtUtc,
    responseDeadlineUtc,
    isReplay,
  ];
}

/// Outcome returned when the Traveler uses their one permitted evidence
/// amendment. This is deliberately separate from [PostTripComplaintSubmission]:
/// the API does not resend booking or submission fields for an amendment.
final class PostTripComplaintEvidenceAmendment extends Equatable {
  const PostTripComplaintEvidenceAmendment({
    required this.complaintId,
    required this.evidenceAmendmentUsedAtUtc,
    required this.evidenceCount,
    required this.evidenceTotalBytes,
    required this.isReplay,
  });

  final int complaintId;
  final DateTime evidenceAmendmentUsedAtUtc;
  final int evidenceCount;
  final int evidenceTotalBytes;
  final bool isReplay;

  @override
  List<Object?> get props => [
    complaintId,
    evidenceAmendmentUsedAtUtc,
    evidenceCount,
    evidenceTotalBytes,
    isReplay,
  ];
}

final class MyPostTripComplaint extends Equatable {
  const MyPostTripComplaint({
    required this.complaintId,
    required this.bookingId,
    required this.bookingCode,
    required this.tourTitle,
    required this.status,
    required this.reasonCategory,
    required this.submittedAtUtc,
    required this.responseDeadlineUtc,
    required this.evidenceCount,
  });
  final int complaintId;
  final int bookingId;
  final String bookingCode;
  final String tourTitle;
  final String status;
  final PostTripComplaintReasonCategory reasonCategory;
  final DateTime submittedAtUtc;
  final DateTime responseDeadlineUtc;
  final int evidenceCount;
  @override
  List<Object?> get props => [
    complaintId,
    bookingId,
    bookingCode,
    tourTitle,
    status,
    reasonCategory,
    submittedAtUtc,
    responseDeadlineUtc,
    evidenceCount,
  ];
}

final class ComplaintEvidenceDownload {
  const ComplaintEvidenceDownload({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });
  final Uint8List bytes;
  final String fileName;
  final String contentType;
}
