import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/data/datasources/post_trip_complaint_remote_data_source.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/repositories/post_trip_complaint_repository.dart';

final class PostTripComplaintRepositoryImpl
    implements PostTripComplaintRepository {
  const PostTripComplaintRepositoryImpl(this._remote);
  final PostTripComplaintRemoteDataSource _remote;
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ErrorMapper.toFailure(error);
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<PostTripComplaintContext> getContext(int bookingId) =>
      _guard(() => _remote.getContext(bookingId));
  @override
  Future<PostTripComplaintSubmission> submit({
    required int bookingId,
    required String idempotencyKey,
    required PostTripComplaintReasonCategory category,
    required String detail,
    required List<SelectedEvidence> evidence,
  }) => _guard(
    () => _remote.submit(
      bookingId: bookingId,
      idempotencyKey: idempotencyKey,
      category: category,
      detail: detail,
      evidence: evidence,
    ),
  );
  @override
  Future<PostTripComplaintEvidenceAmendment> amendEvidence({
    required int bookingId,
    required String idempotencyKey,
    required List<SelectedEvidence> evidence,
  }) => _guard(
    () => _remote.amendEvidence(
      bookingId: bookingId,
      idempotencyKey: idempotencyKey,
      evidence: evidence,
    ),
  );
  @override
  Future<List<MyPostTripComplaint>> listMine() => _guard(_remote.listMine);
  @override
  Future<ComplaintEvidenceDownload> downloadEvidence({
    required int bookingId,
    required int evidenceId,
  }) => _guard(
    () =>
        _remote.downloadEvidence(bookingId: bookingId, evidenceId: evidenceId),
  );
}
