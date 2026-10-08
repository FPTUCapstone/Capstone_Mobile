import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';

final class TourOperatorRegistration {
  const TourOperatorRegistration({
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.companyName,
    required this.businessLicenseNo,
    required this.taxCode,
    required this.contactPerson,
    required this.businessLicenseDocument,
    required this.acceptedTerms,
    this.businessAddress,
    this.contactPhone,
    this.supportingDocuments = const [],
  });

  final String email;
  final String password;
  final String confirmPassword;
  final String companyName;
  final String businessLicenseNo;
  final String taxCode;
  final String contactPerson;
  final String? businessAddress;
  final String? contactPhone;
  final OperatorDocumentUpload? businessLicenseDocument;
  final List<OperatorDocumentUpload> supportingDocuments;
  final bool acceptedTerms;
}

final class TourOperatorRegistrationResult extends Equatable {
  const TourOperatorRegistrationResult({
    required this.userId,
    required this.applicationStatus,
    required this.messageCode,
  });

  final int userId;
  final String applicationStatus;
  final String messageCode;

  @override
  List<Object?> get props => [userId, applicationStatus, messageCode];
}

final class OperatorVerificationStart {
  const OperatorVerificationStart({
    required this.emailSent,
    required this.alreadyVerified,
  });

  final bool emailSent;
  final bool alreadyVerified;
}

final class TourOperatorRegistrationOutcome {
  const TourOperatorRegistrationOutcome({
    required this.registration,
    required this.verificationSynced,
  });

  final TourOperatorRegistrationResult registration;
  final bool verificationSynced;
}
