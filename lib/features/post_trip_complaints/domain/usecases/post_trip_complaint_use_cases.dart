import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/repositories/post_trip_complaint_repository.dart';

final class GetPostTripComplaintContext {
  const GetPostTripComplaintContext(this._repository);
  final PostTripComplaintRepository _repository;
  Future<PostTripComplaintContext> call(int bookingId) =>
      _repository.getContext(bookingId);
}

final class SubmitPostTripComplaint {
  const SubmitPostTripComplaint(this._repository);
  final PostTripComplaintRepository _repository;
  Future<PostTripComplaintSubmission> call({
    required int bookingId,
    required String idempotencyKey,
    required PostTripComplaintReasonCategory category,
    required String detail,
    required List<SelectedEvidence> evidence,
  }) => _repository.submit(
    bookingId: bookingId,
    idempotencyKey: idempotencyKey,
    category: category,
    detail: detail,
    evidence: evidence,
  );
}

final class AmendPostTripComplaintEvidence {
  const AmendPostTripComplaintEvidence(this._repository);
  final PostTripComplaintRepository _repository;
  Future<PostTripComplaintEvidenceAmendment> call({
    required int bookingId,
    required String idempotencyKey,
    required List<SelectedEvidence> evidence,
  }) => _repository.amendEvidence(
    bookingId: bookingId,
    idempotencyKey: idempotencyKey,
    evidence: evidence,
  );
}

final class ListMyPostTripComplaints {
  const ListMyPostTripComplaints(this._repository);
  final PostTripComplaintRepository _repository;
  Future<List<MyPostTripComplaint>> call() => _repository.listMine();
}

final class DownloadPostTripComplaintEvidence {
  const DownloadPostTripComplaintEvidence(this._repository);
  final PostTripComplaintRepository _repository;
  Future<ComplaintEvidenceDownload> call({
    required int bookingId,
    required int evidenceId,
  }) => _repository.downloadEvidence(
    bookingId: bookingId,
    evidenceId: evidenceId,
  );
}
