import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/repositories/post_trip_complaint_repository.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/usecases/post_trip_complaint_use_cases.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_cubit.dart';

class _UnusedRepository implements PostTripComplaintRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RefreshFailureRepository extends _UnusedRepository {
  Object? submitError;
  final keys = <String>[];
  int reads = 0;

  @override
  Future<PostTripComplaintContext> getContext(int bookingId) async {
    if (++reads > 1) throw StateError('Refresh unavailable');
    return PostTripComplaintContext(
      bookingId: bookingId,
      bookingCode: 'BK-42',
      tourTitle: 'Test tour',
      endAtUtc: DateTime.utc(2026, 11, 15),
      submissionDeadlineUtc: DateTime.utc(2026, 11, 18),
      canSubmit: true,
      canAmendEvidence: false,
    );
  }

  @override
  Future<PostTripComplaintSubmission> submit({
    required int bookingId,
    required String idempotencyKey,
    required PostTripComplaintReasonCategory category,
    required String detail,
    required List<SelectedEvidence> evidence,
  }) async {
    keys.add(idempotencyKey);
    if (submitError != null) throw submitError!;
    return PostTripComplaintSubmission(
      complaintId: 1,
      bookingId: bookingId,
      status: 'AwaitingOperatorResponse',
      submittedAtUtc: DateTime.utc(2026, 11, 16),
      responseDeadlineUtc: DateTime.utc(2026, 11, 23),
      isReplay: keys.length > 1,
    );
  }
}

void main() {
  late PostTripComplaintCubit cubit;
  setUp(() {
    final repository = _UnusedRepository();
    cubit = PostTripComplaintCubit(
      bookingId: 42,
      getContext: GetPostTripComplaintContext(repository),
      submit: SubmitPostTripComplaint(repository),
      amend: AmendPostTripComplaintEvidence(repository),
      download: DownloadPostTripComplaintEvidence(repository),
    );
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  SelectedEvidence evidence(String name, {int size = 1}) => SelectedEvidence(
    name: name,
    sizeBytes: size,
    contentType: 'image/png',
    bytes: Uint8List(1),
  );

  test('rejects a sixth attachment and preserves the existing selection', () {
    final valid = List.generate(5, (i) => evidence('$i.png'));
    cubit.setEvidence(valid);
    cubit.setEvidence([...valid, evidence('sixth.png')]);
    expect(cubit.state.evidence, valid);
    expect(cubit.state.message, isNotNull);
  });

  test('rejects oversized evidence without replacing valid attachments', () {
    final valid = [evidence('valid.png')];
    cubit.setEvidence(valid);
    cubit.setEvidence([...valid, evidence('large.png', size: 10485761)]);
    expect(cubit.state.evidence, valid);
    expect(cubit.state.message, isNotNull);
    cubit.setEvidence([]);
    expect(cubit.state.message, isNull);
  });

  test('late file selection after disposal does not emit', () async {
    await cubit.close();
    expect(() => cubit.setEvidence([evidence('late.png')]), returnsNormally);
    expect(() => cubit.setDetail('late detail'), returnsNormally);
    expect(cubit.state.evidence, isEmpty);
  });

  test('distinguishes missing category from an overlong detail', () async {
    await cubit.close();
    final repository = _RefreshFailureRepository();
    cubit = PostTripComplaintCubit(
      bookingId: 42,
      getContext: GetPostTripComplaintContext(repository),
      submit: SubmitPostTripComplaint(repository),
      amend: AmendPostTripComplaintEvidence(repository),
      download: DownloadPostTripComplaintEvidence(repository),
    );
    await cubit.load();
    cubit.setDetail('Valid details');
    await cubit.submit();
    expect(cubit.state.message, 'Vui lòng chọn danh mục lý do.');
    cubit.setCategory(PostTripComplaintReasonCategory.other);
    cubit.setDetail('a' * 2001);
    await cubit.submit();
    expect(cubit.state.message, contains('2.000'));
    expect(repository.keys, isEmpty);
  });

  for (final failure in [
    const NetworkFailure(),
    const RateLimitFailure(),
    const AuthenticationFailure(),
  ]) {
    test('actionable message for ${failure.runtimeType}', () async {
      await cubit.close();
      final repository = _RefreshFailureRepository()..submitError = failure;
      cubit = PostTripComplaintCubit(
        bookingId: 42,
        getContext: GetPostTripComplaintContext(repository),
        submit: SubmitPostTripComplaint(repository),
        amend: AmendPostTripComplaintEvidence(repository),
        download: DownloadPostTripComplaintEvidence(repository),
      );
      await cubit.load();
      cubit.setCategory(PostTripComplaintReasonCategory.other);
      cubit.setDetail('Valid detail');
      await cubit.submit();
      expect(
        cubit.state.message,
        contains(switch (failure) {
          NetworkFailure() => 'kết nối mạng',
          RateLimitFailure() => 'đợi',
          _ => 'đăng nhập',
        }),
      );
    });
  }

  test(
    'keeps submission key when success is followed by refresh failure',
    () async {
      await cubit.close();
      final repository = _RefreshFailureRepository();
      cubit = PostTripComplaintCubit(
        bookingId: 42,
        getContext: GetPostTripComplaintContext(repository),
        submit: SubmitPostTripComplaint(repository),
        amend: AmendPostTripComplaintEvidence(repository),
        download: DownloadPostTripComplaintEvidence(repository),
      );
      await cubit.load();
      cubit.setCategory(PostTripComplaintReasonCategory.serviceQuality);
      cubit.setDetail('Service was different from the description.');
      await cubit.submit();
      await cubit.submit();
      expect(repository.keys, hasLength(2));
      expect(repository.keys[1], repository.keys[0]);
    },
  );
}
