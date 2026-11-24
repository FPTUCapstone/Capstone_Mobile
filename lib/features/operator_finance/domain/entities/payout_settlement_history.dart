/// Read-only settlement row. Vocabulary is mapped to safe display labels in UI.
final class PayoutSettlement {
  const PayoutSettlement({
    required this.settlementId,
    required this.batchId,
    required this.bookingId,
    required this.tourOperatorUserId,
    required this.runDate,
    required this.kind,
    required this.payoutAmount,
    required this.status,
    required this.transferReference,
  });
  final int? settlementId;
  final int? batchId;
  final int bookingId;
  final int tourOperatorUserId;
  final DateTime? runDate;
  final String kind;
  final num payoutAmount;
  final String status;
  final String? transferReference;
}

final class SettlementHistory {
  const SettlementHistory({
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.items,
  });
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final List<PayoutSettlement> items;
}
