import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/repositories/post_trip_complaint_repository.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/usecases/post_trip_complaint_use_cases.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_cubit.dart';

class _Repository implements PostTripComplaintRepository {
  @override
  Future<PostTripComplaintContext> getContext(int bookingId) async =>
      PostTripComplaintContext(
        bookingId: bookingId,
        bookingCode: null,
        tourTitle: null,
        endAtUtc: DateTime.utc(2026),
        submissionDeadlineUtc: DateTime.utc(2026, 1, 4),
        canSubmit: false,
        canAmendEvidence: false,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void registerHistoryComplaintFixture() {
  final repository = _Repository();
  serviceLocator.registerFactoryParam<PostTripComplaintCubit, int, void>(
    (id, _) => PostTripComplaintCubit(
      bookingId: id,
      getContext: GetPostTripComplaintContext(repository),
      submit: SubmitPostTripComplaint(repository),
      amend: AmendPostTripComplaintEvidence(repository),
      download: DownloadPostTripComplaintEvidence(repository),
    ),
  );
}

void unregisterHistoryComplaintFixture() {
  serviceLocator.unregister<PostTripComplaintCubit>();
}
