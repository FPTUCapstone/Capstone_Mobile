import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/data/repositories/operator_application_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';

final class _Storage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => 'dummy-token';
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}

final class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, this.body = '{}'});

  final int status;
  final String body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late DioClient client;
  late _Adapter adapter;
  late OperatorApplicationRepository repository;

  void setup(int status, String body) {
    adapter = _Adapter(status: status, body: body);
    client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
      ),
      secureStorage: _Storage(),
    );
    client.dio.httpClientAdapter = adapter;
    repository = OperatorApplicationRepositoryImpl(client);
  }

  group('OperatorApplicationRepositoryImpl', () {
    test(
      'fetchApplication targets /api/v1/operator/application and parses rejected application',
      () async {
        final responseJson = jsonEncode({
          'userId': 12,
          'userStatus': 'Active',
          'approvalStatus': 'Rejected',
          'companyName': 'Ocean Tours Ltd',
          'businessLicenseNo': 'BL-12345',
          'taxCode': 'TX-67890',
          'contactPerson': 'John Doe',
          'businessAddress': '123 Beach Rd',
          'contactPhone': '0901234567',
          'rejectionReason': 'Invalid business license document provided.',
          'reviewedAtUtc': '2026-10-09T10:00:00.000Z',
          'resubmissionCount': 1,
          'documents': [
            {
              'documentId': 101,
              'documentType': 'BusinessLicense',
              'status': 'Rejected',
              'uploadedAtUtc': '2026-10-08T08:00:00.000Z',
              'downloadUrl': 'https://storage.example.com/doc101.pdf',
              'downloadUrlExpiresAtUtc': '2026-10-09T11:00:00.000Z',
            },
          ],
        });

        setup(200, responseJson);

        final result = await repository.fetchApplication();

        expect(adapter.request?.path, '/api/v1/operator/application');
        expect(result.userId, 12);
        expect(result.approvalStatus, 'Rejected');
        expect(result.companyName, 'Ocean Tours Ltd');
        expect(result.taxCode, 'TX-67890');
        expect(
          result.rejectionReason,
          'Invalid business license document provided.',
        );
        expect(result.resubmissionCount, 1);
        expect(result.documents.length, 1);
        expect(result.documents.first.documentId, 101);
      },
    );

    test(
      'resubmitApplication targets /api/v1/operator/application/resubmit',
      () async {
        final responseJson = jsonEncode({
          'userId': 12,
          'userStatus': 'PendingApproval',
          'approvalStatus': 'PendingApproval',
          'messageCode': 'MSG162',
          'message': 'Application resubmitted successfully.',
          'updatedAtUtc': '2026-10-10T08:00:00.000Z',
          'resubmissionCount': 2,
        });

        setup(200, responseJson);

        await repository.resubmitApplication(
          ResubmitOperatorApplication(
            companyName: 'Ocean Tours Ltd',
            businessLicenseNo: 'BL-12345',
            taxCode: 'TX-67890',
            contactPerson: 'John Doe',
            businessLicenseDocument: OperatorDocumentUpload(
              fileName: 'license.pdf',
              contentType: 'application/pdf',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
            supportingDocuments: [],
          ),
        );

        expect(adapter.request?.path, '/api/v1/operator/application/resubmit');
      },
    );
  });
}
