import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/data/datasources/partial_refund_proposal_remote_data_source.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/repositories/partial_refund_proposal_repository.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/resources/partial_refund_proposal_en.dart';

/// Backend `errorCode` for MSG165 (answered already, or past the 72-hour deadline).
const partialRefundResponseClosedCode =
    'complaint.partial_refund.response_closed';

final class PartialRefundProposalRepositoryImpl
    implements PartialRefundProposalRepository {
  const PartialRefundProposalRepositoryImpl(this._remote);
  final PartialRefundProposalRemoteDataSource _remote;

  @override
  Future<PartialRefundProposal> getProposal(int complaintId) =>
      _guard(() => _remote.getProposal(complaintId));

  @override
  Future<PartialRefundResponseResult> respond(
    int complaintId,
    PartialRefundDecision decision,
  ) => _guard(() => _remote.respond(complaintId, decision));

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      if (ErrorMapper.extractErrorCode(error.response?.data) ==
          partialRefundResponseClosedCode) {
        throw const ConflictFailure(
          PartialRefundProposalStrings.responseClosed,
        );
      }
      throw ErrorMapper.toFailure(error);
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
