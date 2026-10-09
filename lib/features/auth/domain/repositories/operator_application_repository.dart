import 'package:trip_mate_mobile/features/auth/domain/entities/operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';

final class ResubmitOperatorApplication {
  const ResubmitOperatorApplication({
    required this.companyName,
    required this.businessLicenseNo,
    required this.taxCode,
    required this.contactPerson,
    required this.supportingDocuments,
    this.businessAddress,
    this.contactPhone,
    this.businessLicenseDocument,
  });

  final String companyName;
  final String businessLicenseNo;
  final String taxCode;
  final String contactPerson;
  final String? businessAddress;
  final String? contactPhone;
  final OperatorDocumentUpload? businessLicenseDocument;
  final List<OperatorDocumentUpload> supportingDocuments;
}

abstract interface class OperatorApplicationRepository {
  Future<OperatorApplication> fetchApplication();
  Future<void> resubmitApplication(ResubmitOperatorApplication input);
}

final class OperatorApplicationFailure implements Exception {
  const OperatorApplicationFailure(this.code, {this.fieldErrors = const {}});
  final String code;
  final Map<String, String> fieldErrors;
}
