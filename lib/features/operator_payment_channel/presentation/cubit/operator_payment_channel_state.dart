import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/domain/entities/payment_channel_status.dart';

enum PaymentChannelLoadStatus { idle, loading, success, failure }

enum PaymentChannelActionStatus {
  idle,
  submitting,
  verifying,
  success,
  failure,
}

final class OperatorPaymentChannelState extends Equatable {
  const OperatorPaymentChannelState({
    this.loadStatus = PaymentChannelLoadStatus.idle,
    this.actionStatus = PaymentChannelActionStatus.idle,
    this.channel,
    this.loadError,
    this.actionError,
  });

  final PaymentChannelLoadStatus loadStatus;
  final PaymentChannelActionStatus actionStatus;
  final PaymentChannelStatus? channel;
  final String? loadError;
  final String? actionError;

  bool get isLoading => loadStatus == PaymentChannelLoadStatus.loading;
  bool get isSubmitting =>
      actionStatus == PaymentChannelActionStatus.submitting;
  bool get isVerifying => actionStatus == PaymentChannelActionStatus.verifying;
  bool get isBusy => isSubmitting || isVerifying;

  OperatorPaymentChannelState copyWith({
    PaymentChannelLoadStatus? loadStatus,
    PaymentChannelActionStatus? actionStatus,
    PaymentChannelStatus? channel,
    String? loadError,
    String? actionError,
    bool clearActionError = false,
  }) => OperatorPaymentChannelState(
    loadStatus: loadStatus ?? this.loadStatus,
    actionStatus: actionStatus ?? this.actionStatus,
    channel: channel ?? this.channel,
    loadError: loadError ?? this.loadError,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );

  @override
  List<Object?> get props => [
    loadStatus,
    actionStatus,
    channel,
    loadError,
    actionError,
  ];
}
