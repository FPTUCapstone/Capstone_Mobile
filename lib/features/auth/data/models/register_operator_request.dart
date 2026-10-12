import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';

final class RegisterOperatorRequest {
  const RegisterOperatorRequest(this.registration, this.firebaseIdToken);

  final TourOperatorRegistration registration;
  final String firebaseIdToken;

  FormData toFormData() {
    final form = FormData();
    void field(String name, String value) =>
        form.fields.add(MapEntry(name, value));
    void optionalField(String name, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        field(name, value.trim());
      }
    }

    void file(String name, OperatorDocumentUpload document) {
      form.files.add(
        MapEntry(
          name,
          MultipartFile.fromBytes(
            document.bytes,
            filename: document.fileName,
            contentType: DioMediaType.parse(document.contentType),
          ),
        ),
      );
    }

    field('firebaseIdToken', firebaseIdToken);
    field('email', registration.email);
    field('password', registration.password);
    field('confirmPassword', registration.confirmPassword);
    field('companyName', registration.companyName);
    field('businessLicenseNo', registration.businessLicenseNo);
    field('taxCode', registration.taxCode);
    field('contactPerson', registration.contactPerson);
    optionalField('businessAddress', registration.businessAddress);
    optionalField('contactPhone', registration.contactPhone);
    field('acceptTerms', registration.acceptedTerms.toString());
    final licence = registration.businessLicenseDocument;
    if (licence != null) file('businessLicenseDocument', licence);
    for (final document in registration.supportingDocuments) {
      file('supportingDocuments', document);
    }
    return form;
  }
}
