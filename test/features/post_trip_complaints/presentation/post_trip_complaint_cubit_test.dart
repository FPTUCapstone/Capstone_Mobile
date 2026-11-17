import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/repositories/post_trip_complaint_repository.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/usecases/post_trip_complaint_use_cases.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_cubit.dart';

void main() {
  test(
    'uses a new amendment idempotency key when selected evidence changes',
    () async {
      final repository = _Repository();
      final cubit = PostTripComplaintCubit(
        bookingId: 7,
        getContext: GetPostTripComplaintContext(repository),
        submit: SubmitPostTripComplaint(repository),
        amend: AmendPostTripComplaintEvidence(repository),
        download: DownloadPostTripComplaintEvidence(repository),
      );
      await cubit.load();

      final first = _evidence('one.png', [1]);
      final second = _evidence('two.png', [2]);
      await cubit.amend([first]);
      await cubit.amend([second]);
      await cubit.amend([second]);

      expect(repository.amendmentKeys, hasLength(3));
      expect(repository.amendmentKeys[0], isNot(repository.amendmentKeys[1]));
      expect(repository.amendmentKeys[1], repository.amendmentKeys[2]);
      await cubit.close();
    },
  );
}

SelectedEvidence _evidence(String name, List<int> bytes) => SelectedEvidence(
  name: name,
  sizeBytes: bytes.length,
  contentType: 'image/png',
  bytes: Uint8List.fromList(bytes),
);

final class _Repository implements PostTripComplaintRepository {
  final amendmentKeys = <String>[];

  @override
  Future<PostTripComplaintContext> getContext(int bookingId) async =>
      PostTripComplaintContext(
        bookingId: bookingId,
        bookingCode: 'BK-7',
        tourTitle: 'Tour',
        endAtUtc: DateTime.utc(2026, 11, 1),
        submissionDeadlineUtc: DateTime.utc(2026, 11, 4),
        canSubmit: false,
        canAmendEvidence: true,
        complaint: ExistingPostTripComplaint(
          id: 1,
          status: 'AwaitingOperatorResponse',
          reasonCategory: PostTripComplaintReasonCategory.other,
          reasonDetail: 'Detail',
          submittedAtUtc: DateTime.utc(2026, 11, 1),
          responseDeadlineUtc: DateTime.utc(2026, 11, 8),
          evidence: const [],
        ),
      );

  @override
  Future<PostTripComplaintEvidenceAmendment> amendEvidence({
    required int bookingId,
    required String idempotencyKey,
    required List<SelectedEvidence> evidence,
  }) async {
    amendmentKeys.add(idempotencyKey);
    throw const ServerFailure();
  }

  @override
  Future<PostTripComplaintSubmission> submit({
    required int bookingId,
    required String idempotencyKey,
    required PostTripComplaintReasonCategory category,
    required String detail,
    required List<SelectedEvidence> evidence,
  }) => throw UnimplementedError();
  @override
  Future<List<MyPostTripComplaint>> listMine() => throw UnimplementedError();
  @override
  Future<ComplaintEvidenceDownload> downloadEvidence({
    required int bookingId,
    required int evidenceId,
  }) => throw UnimplementedError();
}
