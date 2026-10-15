import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';

final class OperatorApplicationRepositoryImpl
    implements OperatorApplicationRepository {
  const OperatorApplicationRepositoryImpl(this._client);
  final DioClient _client;

  @override
  Future<OperatorApplication> fetchApplication() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/v1/operator/application',
      );
      return _application(response.data);
    } on DioException catch (error) {
      throw _failure(error);
    } on FormatException {
      throw const OperatorApplicationFailure('MSG127');
    }
  }

  @override
  Future<void> resubmitApplication(ResubmitOperatorApplication input) async {
    final values = <String, dynamic>{
      'companyName': input.companyName.trim(),
      'businessLicenseNo': input.businessLicenseNo.trim(),
      'taxCode': input.taxCode.trim(),
      'contactPerson': input.contactPerson.trim(),
      if (input.businessAddress?.trim().isNotEmpty ?? false)
        'businessAddress': input.businessAddress!.trim(),
      if (input.contactPhone?.trim().isNotEmpty ?? false)
        'contactPhone': input.contactPhone!.trim(),
      if (input.businessLicenseDocument != null)
        'businessLicenseDocument': _multipart(input.businessLicenseDocument!),
      'supportingDocuments': input.supportingDocuments.map(_multipart).toList(),
    };
    try {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/api/v1/operator/application/resubmit',
        data: FormData.fromMap(values, ListFormat.multi),
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = response.data;
      if (data?['messageCode'] != 'MSG162' ||
          data?['userStatus'] != 'PendingApproval' ||
          data?['approvalStatus'] != 'PendingApproval') {
        throw const FormatException('Invalid resubmit response.');
      }
    } on DioException catch (error) {
      throw _failure(error);
    } on FormatException {
      throw const OperatorApplicationFailure('MSG127');
    }
  }

  MultipartFile _multipart(OperatorDocumentUpload document) =>
      MultipartFile.fromBytes(
        document.bytes,
        filename: document.fileName,
        contentType: DioMediaType.parse(document.contentType),
      );

  OperatorApplication _application(Map<String, dynamic>? data) {
    if (data == null || data['userId'] is! int || data['documents'] is! List) {
      throw const FormatException('Invalid application response.');
    }
    DateTime? optionalDate(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toUtc() : null;
    final documents = <OperatorApplicationDocument>[];
    for (final raw in data['documents'] as List) {
      if (raw is! Map<String, dynamic> ||
          raw['documentId'] is! int ||
          raw['documentType'] is! String ||
          raw['status'] is! String ||
          optionalDate(raw['uploadedAtUtc']) == null) {
        throw const FormatException('Invalid document response.');
      }
      documents.add(
        OperatorApplicationDocument(
          documentId: raw['documentId'] as int,
          documentType: raw['documentType'] as String,
          status: raw['status'] as String,
          uploadedAtUtc: optionalDate(raw['uploadedAtUtc'])!,
          downloadUrl: raw['downloadUrl'] is String
              ? Uri.tryParse(raw['downloadUrl'] as String)
              : null,
          downloadUrlExpiresAtUtc: optionalDate(raw['downloadUrlExpiresAtUtc']),
        ),
      );
    }
    String required(String key) => data[key] is String
        ? data[key] as String
        : throw const FormatException();
    return OperatorApplication(
      userId: data['userId'] as int,
      userStatus: required('userStatus'),
      approvalStatus: required('approvalStatus'),
      companyName: required('companyName'),
      businessLicenseNo: required('businessLicenseNo'),
      taxCode: required('taxCode'),
      contactPerson: required('contactPerson'),
      businessAddress: data['businessAddress'] as String?,
      contactPhone: data['contactPhone'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      reviewedAtUtc: optionalDate(data['reviewedAtUtc']),
      resubmissionCount: data['resubmissionCount'] is int
          ? data['resubmissionCount'] as int
          : 0,
      documents: documents,
    );
  }

  OperatorApplicationFailure _failure(DioException error) {
    final data = error.response?.data;
    String? code;
    final fields = <String, String>{};
    if (data is Map<String, dynamic>) {
      code = data['errorCode'] as String?;
      final rawErrors = data['errors'];
      if (rawErrors is Map<String, dynamic>) {
        for (final entry in rawErrors.entries) {
          final value = entry.value;
          if (value is List && value.isNotEmpty && value.first is String) {
            fields[_camelCase(entry.key)] = value.first as String;
          }
          if (value is String) {
            fields[_camelCase(entry.key)] = value;
          }
        }
      }
    }
    return OperatorApplicationFailure(
      code ??
          (error.response?.statusCode == 401 ? 'UNAUTHENTICATED' : 'MSG127'),
      fieldErrors: fields,
    );
  }

  String _camelCase(String value) =>
      value.isEmpty ? value : '${value[0].toLowerCase()}${value.substring(1)}';
}
