import 'dart:typed_data';

enum OperatorContractStatus { pendingSignature, signed, voided }

enum OperatorContractDocumentState {
  needsSignerDetails,
  processing,
  ready,
  failed,
}

final class ContractOtpPolicy {
  const ContractOtpPolicy({
    required this.timeToLiveSeconds,
    required this.resendCooldownSeconds,
    required this.maxFailedAttempts,
    required this.consentVersion,
  });
  final int timeToLiveSeconds;
  final int resendCooldownSeconds;
  final int maxFailedAttempts;
  final String consentVersion;
}

final class OperatorContract {
  const OperatorContract({
    required this.id,
    required this.status,
    required this.documentState,
    required this.title,
    required this.templateVersion,
    required this.companyName,
    required this.taxCode,
    required this.businessLicenseNo,
    required this.businessAddress,
    required this.operatorEmail,
    required this.signerName,
    required this.signerTitle,
    required this.signerCapacity,
    required this.rowVersion,
    required this.approvedAtUtc,
    required this.otpPolicy,
    required bool canPrepare,
    required bool canSign,
    this.acceptedContentSha256,
    this.unsignedDocumentSha256,
    this.signedDocumentSha256,
    this.signedAtUtc,
    this.errorCode,
  }) : _canPrepare = canPrepare,
       _canSign = canSign;
  final String id,
      title,
      companyName,
      taxCode,
      businessLicenseNo,
      businessAddress,
      operatorEmail;
  final String signerName, signerTitle, signerCapacity, rowVersion;
  final int templateVersion;
  final OperatorContractStatus status;
  final OperatorContractDocumentState documentState;
  final String? acceptedContentSha256,
      unsignedDocumentSha256,
      signedDocumentSha256,
      errorCode;
  final DateTime approvedAtUtc;
  final DateTime? signedAtUtc;
  final ContractOtpPolicy otpPolicy;
  final bool _canPrepare, _canSign;
  bool get isSigned => status == OperatorContractStatus.signed;
  bool get canPrepare =>
      status == OperatorContractStatus.pendingSignature && _canPrepare;
  bool get canSign =>
      status == OperatorContractStatus.pendingSignature &&
      documentState == OperatorContractDocumentState.ready &&
      _canSign &&
      acceptedContentSha256 != null &&
      unsignedDocumentSha256 != null;
  OperatorContract withRowVersion(String value) => OperatorContract(
    id: id,
    status: status,
    documentState: documentState,
    title: title,
    templateVersion: templateVersion,
    companyName: companyName,
    taxCode: taxCode,
    businessLicenseNo: businessLicenseNo,
    businessAddress: businessAddress,
    operatorEmail: operatorEmail,
    signerName: signerName,
    signerTitle: signerTitle,
    signerCapacity: signerCapacity,
    rowVersion: value,
    approvedAtUtc: approvedAtUtc,
    otpPolicy: otpPolicy,
    canPrepare: _canPrepare,
    canSign: _canSign,
    acceptedContentSha256: acceptedContentSha256,
    unsignedDocumentSha256: unsignedDocumentSha256,
    signedDocumentSha256: signedDocumentSha256,
    signedAtUtc: signedAtUtc,
    errorCode: errorCode,
  );
}

final class ContractSigningChallenge {
  const ContractSigningChallenge({
    required this.id,
    required this.expiresAtUtc,
    required this.resendAtUtc,
    required this.rowVersion,
    required this.maskedEmail,
  });
  final String id, rowVersion, maskedEmail;
  final DateTime expiresAtUtc, resendAtUtc;
}

final class ContractSignatureSubmission {
  const ContractSignatureSubmission({
    required this.expectedContentSha256,
    required this.rowVersion,
    required this.signerName,
    required this.acceptedTerms,
    required this.consentVersion,
    required this.challengeId,
    required this.otp,
    required this.idempotencyKey,
    required this.signature,
  });
  final String expectedContentSha256,
      rowVersion,
      signerName,
      consentVersion,
      challengeId,
      otp,
      idempotencyKey;
  final bool acceptedTerms;
  final Uint8List signature;
}

final class OperatorContractFailure implements Exception {
  const OperatorContractFailure(this.code, {this.statusCode});
  final String code;
  final int? statusCode;
  String get message {
    if (code == 'contract.otp_delivery_unavailable') {
      return 'Chưa thể gửi email xác nhận. Vui lòng thử lại sau.';
    }
    if (code.startsWith('contract.signature_')) {
      return 'Ảnh chữ ký chưa hợp lệ hoặc chưa đủ nét. Vui lòng xóa và vẽ lại.';
    }
    if (code == 'contract.validation') {
      return 'Thông tin xác nhận ký chưa hợp lệ. Hãy kiểm tra thông tin người ký và xác nhận đồng ý.';
    }
    if (statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (statusCode == 403) {
      return 'Tài khoản hiện không được phép thực hiện thao tác này.';
    }
    if (statusCode == 409) {
      return 'Thông tin hợp đồng đã thay đổi. Vui lòng tải lại và kiểm tra trước khi ký.';
    }
    if (statusCode == 429) {
      return 'Bạn thao tác quá nhanh. Vui lòng đợi trước khi gửi lại mã.';
    }
    if (code.contains('otp_expired') || code.contains('challenge_expired')) {
      return 'Mã xác nhận đã hết hạn. Hãy yêu cầu mã mới.';
    }
    if (code.contains('otp_invalid') || code.contains('invalid_otp')) {
      return 'Mã xác nhận chưa đúng. Vui lòng kiểm tra email và nhập lại.';
    }
    if (code.contains('locked') || code.contains('attempts_exhausted')) {
      return 'Mã xác nhận không còn dùng được. Hãy yêu cầu mã mới.';
    }
    if (code == 'document_integrity') {
      return 'Không thể xác minh bản PDF. Hãy tải lại hợp đồng trước khi ký.';
    }
    if (code == 'network') {
      return 'Không thể kết nối. Vui lòng kiểm tra mạng và thử lại.';
    }
    return 'Chưa thể xử lý hợp đồng. Vui lòng thử lại.';
  }
}
