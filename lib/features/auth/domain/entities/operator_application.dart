import 'package:equatable/equatable.dart';

final class OperatorApplicationDocument extends Equatable {
  const OperatorApplicationDocument({
    required this.documentId,
    required this.documentType,
    required this.status,
    required this.uploadedAtUtc,
    this.downloadUrl,
    this.downloadUrlExpiresAtUtc,
  });

  final int documentId;
  final String documentType;
  final String status;
  final DateTime uploadedAtUtc;
  final Uri? downloadUrl;
  final DateTime? downloadUrlExpiresAtUtc;

  @override
  List<Object?> get props => [
    documentId,
    documentType,
    status,
    uploadedAtUtc,
    downloadUrl,
    downloadUrlExpiresAtUtc,
  ];
}

final class OperatorApplication extends Equatable {
  const OperatorApplication({
    required this.userId,
    required this.userStatus,
    required this.approvalStatus,
    required this.companyName,
    required this.businessLicenseNo,
    required this.taxCode,
    required this.contactPerson,
    required this.resubmissionCount,
    required this.documents,
    this.businessAddress,
    this.contactPhone,
    this.rejectionReason,
    this.reviewedAtUtc,
  });

  final int userId;
  final String userStatus;
  final String approvalStatus;
  final String companyName;
  final String businessLicenseNo;
  final String taxCode;
  final String contactPerson;
  final String? businessAddress;
  final String? contactPhone;
  final String? rejectionReason;
  final DateTime? reviewedAtUtc;
  final int resubmissionCount;
  final List<OperatorApplicationDocument> documents;

  bool get isRejected =>
      userStatus == 'Rejected' && approvalStatus == 'Rejected';

  @override
  List<Object?> get props => [
    userId,
    userStatus,
    approvalStatus,
    companyName,
    businessLicenseNo,
    taxCode,
    contactPerson,
    businessAddress,
    contactPhone,
    rejectionReason,
    reviewedAtUtc,
    resubmissionCount,
    documents,
  ];
}
