import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/data/datasources/partial_refund_proposal_remote_data_source.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/data/repositories/partial_refund_proposal_repository_impl.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/resources/partial_refund_proposal_en.dart';

void main() {
  test('a closed response window becomes the MSG165 conflict', () async {
    final repository = PartialRefundProposalRepositoryImpl(
      _ThrowingRemote(
        _problem(409, 'complaint.partial_refund.response_closed'),
      ),
    );

    await expectLater(
      repository.respond(501, PartialRefundDecision.accept),
      throwsA(
        const ConflictFailure(PartialRefundProposalStrings.responseClosed),
      ),
    );
  });

  test('another owner is a permission failure (MSG126)', () async {
    final repository = PartialRefundProposalRepositoryImpl(
      _ThrowingRemote(_problem(403, 'complaint.partial_refund.forbidden')),
    );

    await expectLater(
      repository.getProposal(501),
      throwsA(isA<PermissionFailure>()),
    );
  });

  test('a server error stays a server failure', () async {
    final repository = PartialRefundProposalRepositoryImpl(
      _ThrowingRemote(_problem(500, null)),
    );

    await expectLater(
      repository.respond(501, PartialRefundDecision.decline),
      throwsA(isA<ServerFailure>()),
    );
  });
}

DioException _problem(int statusCode, String? errorCode) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: statusCode,
      data: {'status': statusCode, 'title': 'Problem', 'errorCode': ?errorCode},
    ),
  );
}

final class _ThrowingRemote implements PartialRefundProposalRemoteDataSource {
  const _ThrowingRemote(this._error);
  final Object _error;

  @override
  Future<PartialRefundProposal> getProposal(int complaintId) =>
      Future.error(_error);

  @override
  Future<PartialRefundResponseResult> respond(
    int complaintId,
    PartialRefundDecision decision,
  ) => Future.error(_error);
}
