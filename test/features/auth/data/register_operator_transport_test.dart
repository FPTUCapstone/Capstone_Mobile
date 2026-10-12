import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/data/mappers/operator_registration_mapper.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_operator_request.dart';
import 'package:trip_mate_mobile/features/auth/data/repositories/tour_operator_registration_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';

final class _Storage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => 'old-tripmate-session';
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}

final class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 201, this.body = _success});

  static const _success =
      '{"success":true,"statusCode":201,"data":{"userId":42,"applicationStatus":"PendingApproval","messageCode":"MSG08"}}';
  final int status;
  final String body;
  RequestOptions? request;
  String? wireBody;
  List<int>? wireBytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      wireBytes = await requestStream.expand((bytes) => bytes).toList();
      wireBody = String.fromCharCodes(wireBytes!);
    }
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

final class _TimeoutAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException(
    requestOptions: options,
    type: DioExceptionType.receiveTimeout,
  );

  @override
  void close({bool force = false}) {}
}

TourOperatorRegistration _registration() => TourOperatorRegistration(
  email: 'operator@example.test',
  password: 'Password123!',
  confirmPassword: 'Password123!',
  companyName: 'Trip Operator',
  businessLicenseNo: '79-0123/2026/TCDL-GPLHQT',
  taxCode: '0101234567',
  contactPerson: 'Linh',
  businessAddress: '123 Main Street',
  contactPhone: '0912345678',
  businessLicenseDocument: OperatorDocumentUpload(
    fileName: 'licence.pdf',
    contentType: 'application/pdf',
    bytes: Uint8List.fromList(utf8.encode('%PDF-licence')),
  ),
  supportingDocuments: [
    OperatorDocumentUpload(
      fileName: 'one.png',
      contentType: 'image/png',
      bytes: Uint8List.fromList([137, 80, 78, 71, 1]),
    ),
    OperatorDocumentUpload(
      fileName: 'two.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList([255, 216, 255, 2]),
    ),
  ],
  acceptedTerms: true,
);

void main() {
  test(
    'backend business format codes produce safe field-specific messages',
    () {
      final rejection = const OperatorRegistrationRemoteRejection(400, {
        'errorCode': 'auth.request_invalid',
        'errors': {
          'taxCode': ['OPERATOR_TAX_CODE_INVALID'],
          'businessLicenseNo': ['OPERATOR_TRAVEL_LICENSE_INVALID'],
        },
      }).toDomain();
      expect(rejection.fieldErrors['taxCode']?.single, contains('10 digits'));
      expect(
        rejection.fieldErrors['businessLicenseNo']?.single,
        contains('Travel Licence Number'),
      );
    },
  );

  test('multipart contract has exact keys and repeated file parts', () {
    final form = RegisterOperatorRequest(
      _registration(),
      'firebase-token',
    ).toFormData();
    expect(form.fields.map((part) => part.key), [
      'firebaseIdToken',
      'email',
      'password',
      'confirmPassword',
      'companyName',
      'businessLicenseNo',
      'taxCode',
      'contactPerson',
      'businessAddress',
      'contactPhone',
      'acceptTerms',
    ]);
    expect(form.fields.first.value, 'firebase-token');
    expect(form.fields.last.value, 'true');
    expect(form.files.map((part) => part.key), [
      'businessLicenseDocument',
      'supportingDocuments',
      'supportingDocuments',
    ]);
    expect(form.files.map((part) => part.value.filename), [
      'licence.pdf',
      'one.png',
      'two.jpg',
    ]);
    expect(form.files.first.value.contentType.toString(), 'application/pdf');
    expect(form.files[1].value.contentType.toString(), 'image/png');
    expect(form.files[2].value.contentType.toString(), 'image/jpeg');
    expect(
      form.fields.map((part) => part.key),
      isNot(contains('contactAddress')),
    );
    expect(
      form.files.map((part) => part.key),
      isNot(contains('supportingDocuments[]')),
    );
  });

  test('optional blank fields are omitted', () {
    final input = TourOperatorRegistration(
      email: 'operator@example.test',
      password: 'Password123!',
      confirmPassword: 'Password123!',
      companyName: 'Trip Operator',
      businessLicenseNo: '79-0123/2026/TCDL-GPLHQT',
      taxCode: '0101234567',
      contactPerson: 'Linh',
      businessAddress: ' ',
      contactPhone: '',
      businessLicenseDocument: _registration().businessLicenseDocument,
      acceptedTerms: true,
    );
    final form = RegisterOperatorRequest(input, 'token').toFormData();
    expect(
      form.fields.map((part) => part.key),
      isNot(contains('businessAddress')),
    );
    expect(
      form.fields.map((part) => part.key),
      isNot(contains('contactPhone')),
    );
  });

  test(
    'Vietnamese company, contact and address survive multipart encoding',
    () async {
      final adapter = _Adapter();
      final client = DioClient(
        config: AppConfig(
          environment: Environment.production,
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
        secureStorage: _Storage(),
      );
      client.dio.httpClientAdapter = adapter;
      final repository = TourOperatorRegistrationRepositoryImpl(
        AuthRemoteDataSourceImpl(client),
      );
      const company = 'Công ty Du lịch Đà Nẵng';
      const contact = 'Nguyễn Thị Ánh';
      const address = '123 đường Trần Phú, Đà Nẵng';
      final base = _registration();
      final input = TourOperatorRegistration(
        email: base.email,
        password: base.password,
        confirmPassword: base.confirmPassword,
        companyName: company,
        businessLicenseNo: base.businessLicenseNo,
        taxCode: base.taxCode,
        contactPerson: contact,
        businessAddress: address,
        contactPhone: base.contactPhone,
        businessLicenseDocument: base.businessLicenseDocument,
        supportingDocuments: base.supportingDocuments,
        acceptedTerms: base.acceptedTerms,
      );

      await repository.register(input, 'firebase-token');

      final formFields = RegisterOperatorRequest(
        input,
        'firebase-token',
      ).toFormData().fields;
      expect(
        formFields.singleWhere((field) => field.key == 'companyName').value,
        company,
      );
      expect(
        formFields.singleWhere((field) => field.key == 'contactPerson').value,
        contact,
      );
      expect(
        formFields.singleWhere((field) => field.key == 'businessAddress').value,
        address,
      );
      final wire = utf8.decode(adapter.wireBytes!, allowMalformed: true);
      expect(wire, contains(company));
      expect(wire, contains(contact));
      expect(wire, contains(address));
    },
  );

  group('registration transport', () {
    late DioClient client;
    late AuthRemoteDataSourceImpl source;
    late TourOperatorRegistrationRepositoryImpl repository;

    setUp(() {
      client = DioClient(
        config: AppConfig(
          environment: Environment.production,
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
        secureStorage: _Storage(),
      );
      source = AuthRemoteDataSourceImpl(client);
      repository = TourOperatorRegistrationRepositoryImpl(source);
    });

    test(
      'verified operator confirmation uses Web endpoint without session',
      () async {
        final adapter = _Adapter(
          status: 200,
          body: '{"success":true,"data":{"emailVerified":true}}',
        );
        client.dio.httpClientAdapter = adapter;
        await repository.confirmVerifiedEmail('fresh-firebase-token');
        expect(adapter.request?.path, '/api/v1/auth/web/verify-email');
        expect(adapter.request?.method, 'POST');
        expect(
          adapter.request?.headers['Authorization'],
          'Bearer fresh-firebase-token',
        );
        expect(adapter.request?.data, isNull);
      },
    );

    test(
      'confirmation refuses malformed success instead of granting access',
      () async {
        client.dio.httpClientAdapter = _Adapter(
          status: 200,
          body: '{"success":true,"data":{"emailVerified":false}}',
        );
        await expectLater(
          repository.confirmVerifiedEmail('token'),
          throwsA(isA<OperatorVerificationUncertain>()),
        );
      },
    );

    test('confirmation maps BE rejection to a safe code', () async {
      client.dio.httpClientAdapter = _Adapter(
        status: 401,
        body: '{"title":"internal details","errorCode":"AUTH_TOKEN_INVALID"}',
      );
      await expectLater(
        repository.confirmVerifiedEmail('token'),
        throwsA(
          isA<OperatorVerificationRejected>().having(
            (error) => error.messageCode,
            'messageCode',
            'AUTH_TOKEN_INVALID',
          ),
        ),
      );
    });

    test('201 maps result and sends multipart without saved session', () async {
      final adapter = _Adapter();
      client.dio.httpClientAdapter = adapter;

      final result = await repository.register(
        _registration(),
        'firebase-token',
      );

      expect(result.userId, 42);
      expect(result.applicationStatus, 'PendingApproval');
      expect(result.messageCode, 'MSG08');
      expect(adapter.request?.path, '/api/v1/auth/register/operator');
      expect(adapter.request?.method, 'POST');
      expect(adapter.request?.receiveTimeout, const Duration(seconds: 60));
      expect(client.dio.options.receiveTimeout, const Duration(seconds: 30));
      expect(
        adapter.request?.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        adapter.request?.contentType,
        startsWith('multipart/form-data; boundary='),
      );
      expect(adapter.wireBody, contains('name="businessAddress"'));
      expect(
        RegExp(
          'name="supportingDocuments"',
        ).allMatches(adapter.wireBody!).length,
        2,
      );
      expect(adapter.wireBody, contains('%PDF-licence'));
      expect(adapter.wireBody, contains('filename="one.png"'));
      expect(
        adapter.wireBody,
        contains(String.fromCharCodes([137, 80, 78, 71, 1])),
      );
      expect(
        adapter.wireBody,
        contains(String.fromCharCodes([255, 216, 255, 2])),
      );
    });

    test('400 field-code arrays map to safe inline messages', () async {
      client.dio.httpClientAdapter = _Adapter(
        status: 400,
        body: jsonEncode({
          'errorCode': 'auth.request_invalid',
          'title': 'internal exception',
          'errors': {
            'businessLicenseDocument': ['MSG157', 'MSG158'],
            'acceptTerms': ['MSG_TOS'],
            'companyName': ['internal.unknown'],
          },
        }),
      );
      await expectLater(
        repository.register(_registration(), 'token'),
        throwsA(
          isA<OperatorRegistrationRejected>()
              .having(
                (error) => error.messageCode,
                'code',
                'auth.request_invalid',
              )
              .having(
                (error) => error.fieldErrors['businessLicenseDocument']?.length,
                'document errors',
                2,
              )
              .having(
                (error) => error.fieldErrors['acceptTerms']?.first,
                'terms',
                contains('Terms of Service'),
              )
              .having(
                (error) => error.fieldErrors['companyName']?.first,
                'unknown',
                isNot(contains('internal')),
              ),
        ),
      );
    });

    test(
      'indexed supporting-document errors appear under the upload field',
      () async {
        client.dio.httpClientAdapter = _Adapter(
          status: 400,
          body: jsonEncode({
            'errorCode': 'auth.request_invalid',
            'errors': {
              'supportingDocuments[0]': ['MSG158'],
              'supportingDocuments[1]': ['internal.secret'],
              'supportingDocuments[bad]': ['MSG158'],
              'supportingDocuments': ['auth.request_invalid'],
            },
          }),
        );

        await expectLater(
          repository.register(_registration(), 'token'),
          throwsA(
            isA<OperatorRegistrationRejected>()
                .having(
                  (error) => error.fieldErrors.keys.toList(),
                  'normalized field',
                  ['supportingDocuments'],
                )
                .having(
                  (error) => error.fieldErrors['supportingDocuments']?.length,
                  'all indexed and field-level messages',
                  3,
                )
                .having(
                  (error) => error.fieldErrors.toString(),
                  'safe messages',
                  allOf(
                    contains('not supported'),
                    isNot(contains('internal.secret')),
                  ),
                ),
          ),
        );
      },
    );

    for (final (status, code) in [
      (401, 'AUTH_TOKEN_INVALID'),
      (409, 'MSG159'),
      (409, 'MSG160'),
      (503, 'MSG127'),
    ]) {
      test('$status is a definite rejection with safe code $code', () async {
        client.dio.httpClientAdapter = _Adapter(
          status: status,
          body: jsonEncode({
            'errorCode': code,
            'title': 'secret internal details',
          }),
        );
        await expectLater(
          repository.register(_registration(), 'token'),
          throwsA(
            isA<OperatorRegistrationRejected>()
                .having((error) => error.messageCode, 'code', code)
                .having(
                  (error) => error.fieldErrors.toString(),
                  'fields',
                  isNot(contains('secret')),
                ),
          ),
        );
      });
    }

    for (final status in [413, 415]) {
      test(
        '$status rejects the document without exposing server details',
        () async {
          client.dio.httpClientAdapter = _Adapter(
            status: status,
            body: '{"title":"internal storage information"}',
          );
          await expectLater(
            repository.register(_registration(), 'token'),
            throwsA(isA<OperatorRegistrationRejected>()),
          );
        },
      );
    }

    test('unrecognized server error leaves outcome unknown', () async {
      client.dio.httpClientAdapter = _Adapter(
        status: 500,
        body: '{"title":"internal storage information"}',
      );
      await expectLater(
        repository.register(_registration(), 'token'),
        throwsA(isA<OperatorRegistrationUncertain>()),
      );
    });

    test('timeout leaves registration outcome unknown', () async {
      client.dio.httpClientAdapter = _TimeoutAdapter();
      await expectLater(
        repository.register(_registration(), 'token'),
        throwsA(isA<OperatorRegistrationUncertain>()),
      );
    });

    for (final body in [
      '{"success":true,"data":{"userId":42}}',
      '{"success":false,"data":{"userId":42,"applicationStatus":"PendingApproval","messageCode":"MSG08"}}',
    ]) {
      test('malformed 201 is uncertain', () async {
        client.dio.httpClientAdapter = _Adapter(body: body);
        await expectLater(
          repository.register(_registration(), 'token'),
          throwsA(isA<OperatorRegistrationUncertain>()),
        );
      });
    }
  });
}
