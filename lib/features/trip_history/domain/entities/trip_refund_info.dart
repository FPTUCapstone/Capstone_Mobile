import 'package:equatable/equatable.dart';

enum RefundStatus {
  refunded,
  processing,
  nonRefundable;

  String get label => switch (this) {
    RefundStatus.refunded => 'Refunded',
    RefundStatus.processing => 'Processing',
    RefundStatus.nonRefundable => 'Non-refundable',
  };
}

final class TripRefundInfo extends Equatable {
  const TripRefundInfo({
    required this.status,
    required this.amount,
    required this.channel,
    this.note,
  });

  final RefundStatus status;
  final int amount; // in VND
  final String channel;
  final String? note;

  @override
  List<Object?> get props => [status, amount, channel, note];
}
