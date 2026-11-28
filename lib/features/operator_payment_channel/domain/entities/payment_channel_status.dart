import 'package:equatable/equatable.dart';

enum PaymentChannelState {
  noChannel,
  pendingVerification,
  pendingAdminApproval,
  ready,
  disabled;

  static PaymentChannelState fromString(String value) => switch (value) {
    'NoChannel' => noChannel,
    'PendingVerification' => pendingVerification,
    'PendingAdminApproval' => pendingAdminApproval,
    'Ready' => ready,
    'Disabled' => disabled,
    _ => noChannel,
  };

  bool get isReady => this == ready;
  bool get canBeConfigured => this == noChannel || this == disabled;
}

final class PaymentChannelStatus extends Equatable {
  const PaymentChannelStatus({
    required this.status,
    required this.allowedActions,
    this.channelId,
    this.channelVersion,
    this.beneficiaryAccountNumberMasked,
    this.beneficiaryAccountName,
    this.beneficiaryBankCode,
    this.webhookRegisteredAt,
    this.connectedAt,
    this.lastVerifiedAt,
  });

  final int? channelId;
  final PaymentChannelState status;
  final int? channelVersion;
  final String? beneficiaryAccountNumberMasked;
  final String? beneficiaryAccountName;
  final String? beneficiaryBankCode;
  final DateTime? webhookRegisteredAt;
  final DateTime? connectedAt;
  final DateTime? lastVerifiedAt;
  final List<String> allowedActions;

  bool get canSubmitCredentials =>
      allowedActions.contains('submit_credentials') ||
      allowedActions.contains('re_submit');
  bool get canVerify => allowedActions.contains('verify');

  @override
  List<Object?> get props => [
    channelId,
    status,
    channelVersion,
    beneficiaryAccountNumberMasked,
    beneficiaryAccountName,
    beneficiaryBankCode,
    webhookRegisteredAt,
    connectedAt,
    lastVerifiedAt,
    allowedActions,
  ];
}

final class SubmitCredentialsRequest extends Equatable {
  const SubmitCredentialsRequest({
    required this.clientId,
    required this.apiKey,
    required this.checksumKey,
    required this.beneficiaryAccountNumber,
    required this.beneficiaryAccountName,
    required this.beneficiaryBankCode,
  });

  final String clientId;
  final String apiKey;
  final String checksumKey;
  final String beneficiaryAccountNumber;
  final String beneficiaryAccountName;
  final String beneficiaryBankCode;

  @override
  List<Object?> get props => [
    clientId,
    apiKey,
    checksumKey,
    beneficiaryAccountNumber,
    beneficiaryAccountName,
    beneficiaryBankCode,
  ];
}
