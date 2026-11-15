import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';

abstract interface class PartialRefundProposalRemoteDataSource {
  Future<PartialRefundProposal> getProposal(int complaintId);

  Future<PartialRefundResponseResult> respond(
    int complaintId,
    PartialRefundDecision decision,
  );
}

/// UC-75 Backend contract (`TravelerComplaintsController`).
final class DioPartialRefundProposalRemoteDataSource
    implements PartialRefundProposalRemoteDataSource {
  DioPartialRefundProposalRemoteDataSource(DioClient client)
    : _dio = client.dio;
  final Dio _dio;

  @override
  Future<PartialRefundProposal> getProposal(int complaintId) async {
    final response = await _dio.get<Map<String, dynamic>>(_path(complaintId));
    final raw = _body(response.data);
    final id = _int(raw['complaintId']);
    final bookingId = _int(raw['bookingId']);
    final bookingCode = raw['bookingCode']?.toString().trim();
    final amount = _int(raw['proposedAmount']);
    final deadline = _date(raw['responseDeadlineUtc']);
    final status = PartialRefundProposalStatus.tryFromWire(
      raw['status']?.toString(),
    );
    final canRespond = raw['canRespond'];
    if (id == null ||
        bookingId == null ||
        bookingCode == null ||
        bookingCode.isEmpty ||
        amount == null ||
        amount < 0 ||
        deadline == null ||
        status == null ||
        canRespond is! bool) {
      throw const FormatException('The partial refund proposal is invalid.');
    }
    return PartialRefundProposal(
      complaintId: id,
      bookingId: bookingId,
      bookingCode: bookingCode,
      proposedAmount: amount,
      responseDeadlineUtc: deadline,
      status: status,
      canRespond: canRespond,
    );
  }

  @override
  Future<PartialRefundResponseResult> respond(
    int complaintId,
    PartialRefundDecision decision,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${_path(complaintId)}/response',
      data: {'decision': decision.wireValue},
    );
    final raw = _body(response.data);
    final id = _int(raw['complaintId']);
    final status = PartialRefundProposalStatus.tryFromWire(
      raw['status']?.toString(),
    );
    final respondedAt = _date(raw['respondedAtUtc']);
    if (id == null || status == null || respondedAt == null) {
      throw const FormatException('The partial refund response is invalid.');
    }
    return PartialRefundResponseResult(
      complaintId: id,
      status: status,
      approvedAmount: _int(raw['approvedAmount']),
      respondedAtUtc: respondedAt,
    );
  }

  static String _path(int complaintId) {
    if (complaintId <= 0) {
      throw const FormatException('The complaint id is invalid.');
    }
    return '/api/v1/traveler/complaints/$complaintId/partial-refund-proposal';
  }

  static Map<String, dynamic> _body(Map<String, dynamic>? envelope) {
    final raw = envelope?['data'] is Map<String, dynamic>
        ? envelope!['data'] as Map<String, dynamic>
        : envelope;
    if (raw == null) {
      throw const FormatException('The partial refund response is empty.');
    }
    return raw;
  }

  static int? _int(Object? value) => switch (value) {
    int value => value,
    num value => value.round(),
    String value => num.tryParse(value)?.round(),
    _ => null,
  };

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
