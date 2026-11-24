import 'package:trip_mate_mobile/features/operator_contracts/domain/entities/operator_contract.dart';

final class OperatorContractDto {
  factory OperatorContractDto.fromJson(Map<String, dynamic> json) {
    String string(String key, {bool empty = false}) {
      final value = json[key];
      if (value is! String || (!empty && value.isEmpty)) {
        throw const FormatException('Invalid contract');
      }
      return value;
    }

    String? hash(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value)) {
        throw const FormatException('Invalid document hash');
      }
      return value.toLowerCase();
    }

    final id = string('id');
    if (!RegExp(r'^[1-9]\d*$').hasMatch(id)) {
      throw const FormatException('Invalid contract id');
    }
    final status = switch (string('status')) {
      'PendingSignature' => OperatorContractStatus.pendingSignature,
      'Signed' => OperatorContractStatus.signed,
      'Voided' => OperatorContractStatus.voided,
      _ => throw const FormatException('Unknown contract status'),
    };
    final document = switch (string('documentState')) {
      'NeedsSignerDetails' => OperatorContractDocumentState.needsSignerDetails,
      'Processing' => OperatorContractDocumentState.processing,
      'Ready' => OperatorContractDocumentState.ready,
      'Failed' => OperatorContractDocumentState.failed,
      _ => throw const FormatException('Unknown document state'),
    };
    final policy = json['otpPolicy'];
    if (policy is! Map<String, dynamic>) {
      throw const FormatException('Invalid policy');
    }
    int positive(String key) {
      final value = policy[key];
      if (value is! int || value <= 0) {
        throw const FormatException('Invalid policy');
      }
      return value;
    }

    final consent = policy['consentVersion'];
    if (consent is! String || consent.isEmpty) {
      throw const FormatException('Invalid consent version');
    }
    final version = json['templateVersion'];
    if (version is! int ||
        version <= 0 ||
        json['canPrepare'] is! bool ||
        json['canSign'] is! bool) {
      throw const FormatException('Invalid contract');
    }
    return OperatorContractDto._(
      OperatorContract(
        id: id,
        status: status,
        documentState: document,
        title: string('title'),
        templateVersion: version,
        companyName: string('companyName'),
        taxCode: string('taxCode', empty: true),
        businessLicenseNo: string('businessLicenseNo', empty: true),
        businessAddress: string('businessAddress', empty: true),
        operatorEmail: string('operatorEmail'),
        signerName: string('signerName', empty: true),
        signerTitle: string('signerTitle', empty: true),
        signerCapacity: string('signerCapacity', empty: true),
        rowVersion: string('rowVersion'),
        approvedAtUtc: DateTime.parse(string('approvedAtUtc')).toUtc(),
        signedAtUtc: json['signedAtUtc'] == null
            ? null
            : DateTime.parse(string('signedAtUtc')).toUtc(),
        acceptedContentSha256: hash('acceptedContentSha256'),
        unsignedDocumentSha256: hash('unsignedDocumentSha256'),
        signedDocumentSha256: hash('signedDocumentSha256'),
        errorCode: json['errorCode'] as String?,
        canPrepare: json['canPrepare'] as bool,
        canSign: json['canSign'] as bool,
        otpPolicy: ContractOtpPolicy(
          timeToLiveSeconds: positive('timeToLiveSeconds'),
          resendCooldownSeconds: positive('resendCooldownSeconds'),
          maxFailedAttempts: positive('maxFailedAttempts'),
          consentVersion: consent,
        ),
      ),
    );
  }
  OperatorContractDto._(this._value);
  final OperatorContract _value;
  OperatorContract toDomain() => _value;

  static ContractSigningChallenge challenge(Map<String, dynamic> json) {
    final id = json['challengeId'],
        row = json['rowVersion'],
        email = json['maskedEmail'];
    if (id is! String ||
        id.isEmpty ||
        row is! String ||
        row.isEmpty ||
        email is! String) {
      throw const FormatException('Invalid challenge');
    }
    return ContractSigningChallenge(
      id: id,
      rowVersion: row,
      maskedEmail: email,
      expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
      resendAtUtc: DateTime.parse(json['resendAtUtc'] as String).toUtc(),
    );
  }
}
