import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';

abstract interface class PostTripComplaintRepository {
  Future<PostTripComplaintContext> getContext(int bookingId);
  Future<PostTripComplaintSubmission> submit({
    required int bookingId,
    required String idempotencyKey,
    required PostTripComplaintReasonCategory category,
    required String detail,
    required List<SelectedEvidence> evidence,
  });
  Future<PostTripComplaintEvidenceAmendment> amendEvidence({
    required int bookingId,
    required String idempotencyKey,
    required List<SelectedEvidence> evidence,
  });
  Future<List<MyPostTripComplaint>> listMine();
  Future<ComplaintEvidenceDownload> downloadEvidence({
    required int bookingId,
    required int evidenceId,
  });
}
