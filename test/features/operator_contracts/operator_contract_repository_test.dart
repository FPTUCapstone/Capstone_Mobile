import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/operator_contracts/data/datasources/operator_contract_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_contracts/data/models/operator_contract_dto.dart';
import 'package:trip_mate_mobile/features/operator_contracts/data/repositories/operator_contract_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/entities/operator_contract.dart';
import 'operator_contract_dto_test.dart' show contractPayload;

class _Storage implements SecureStorageService {
  final values = <String, String>{
    AppConstants.accessTokenKey: 'access',
    AppConstants.refreshTokenKey: 'refresh',
  };
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }
}

class _Server implements HttpClientAdapter {
  _Server(this.handler);
  final ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  OperatorContractRepositoryImpl repository(_Server server) {
    final client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test'),
      ),
      secureStorage: _Storage(),
    );
    client.dio.httpClientAdapter = server;
    return OperatorContractRepositoryImpl(
      OperatorContractRemoteDataSource(client),
    );
  }

  test(
    'private PDF uses bearer authentication and exact document hash',
    () async {
      final bytes = Uint8List.fromList('%PDF-test-content'.codeUnits);
      final server = _Server(
        (_) => ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/pdf'],
          },
        ),
      );
      final value = OperatorContractDto.fromJson({
        ...contractPayload(),
        'unsignedDocumentSha256': sha256.convert(bytes).toString(),
      }).toDomain();
      expect(await repository(server).document(value), bytes);
      expect(server.requests.single.headers['Authorization'], 'Bearer access');
      expect(server.requests.single.path, endsWith('/documents/unsigned'));
    },
  );
  test('altered PDF bytes cannot become a reviewed contract', () async {
    final server = _Server(
      (_) => ResponseBody.fromBytes(
        '%PDF-wrong'.codeUnits,
        200,
        headers: {
          Headers.contentTypeHeader: ['application/pdf'],
        },
      ),
    );
    await expectLater(
      repository(
        server,
      ).document(OperatorContractDto.fromJson(contractPayload()).toDomain()),
      throwsA(
        isA<OperatorContractFailure>().having(
          (failure) => failure.code,
          'code',
          'document_integrity',
        ),
      ),
    );
  });
  test(
    'sign sends original opaque ID and bounded PNG multipart without operator ID',
    () async {
      final server = _Server(
        (_) => ResponseBody.fromString(
          jsonEncode(contractPayload(status: 'Signed')),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final value = OperatorContractDto.fromJson(contractPayload()).toDomain();
      await repository(server).sign(
        value,
        ContractSignatureSubmission(
          expectedContentSha256: 'a' * 64,
          rowVersion: 'AQ==',
          signerName: value.signerName,
          acceptedTerms: true,
          consentVersion: 'operator-contract-v1',
          challengeId: 'challenge',
          otp: '123456',
          idempotencyKey: 'key',
          signature: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ),
      );
      expect(server.requests.single.path, contains('9007199254740993/sign'));
      final form = server.requests.single.data as FormData;
      expect(Map.fromEntries(form.fields)['otp'], '123456');
      expect(Map.fromEntries(form.fields), isNot(contains('operatorId')));
      expect(form.files.single.key, 'signature');
      expect(form.files.single.value.contentType.toString(), 'image/png');
    },
  );
}
