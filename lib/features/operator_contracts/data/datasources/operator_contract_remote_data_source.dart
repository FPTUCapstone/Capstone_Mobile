import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/entities/operator_contract.dart';

final class OperatorContractRemoteDataSource {
  const OperatorContractRemoteDataSource(this._client);
  final DioClient _client;
  static const _base = '/api/v1/operator/contracts';

  Future<Map<String, dynamic>?> current() async {
    try {
      return _map((await _client.dio.get<dynamic>('$_base/current')).data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw _failure(error);
    }
  }

  Future<Map<String, dynamic>> prepare(String id, Map<String, dynamic> input) =>
      _post('$_base/$id/prepare', input);
  Future<Map<String, dynamic>> challenge(
    String id,
    Map<String, dynamic> input,
  ) => _post('$_base/$id/signing-challenges', input);
  Future<Map<String, dynamic>> sign(
    String id,
    ContractSignatureSubmission input,
  ) => _post(
    '$_base/$id/sign',
    FormData.fromMap({
      'expectedContentSha256': input.expectedContentSha256,
      'rowVersion': input.rowVersion,
      'signerName': input.signerName,
      'acceptedTerms': input.acceptedTerms.toString(),
      'consentVersion': input.consentVersion,
      'challengeId': input.challengeId,
      'otp': input.otp,
      'idempotencyKey': input.idempotencyKey,
      'signature': MultipartFile.fromBytes(
        input.signature,
        filename: 'signature.png',
        contentType: DioMediaType.parse('image/png'),
      ),
    }),
  );
  Future<Uint8List> document(String id, bool signed) async {
    try {
      final response = await _client.dio.get<List<int>>(
        '$_base/$id/documents/${signed ? 'signed' : 'unsigned'}',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
        ),
      );
      final bytes = Uint8List.fromList(response.data ?? []);
      if (bytes.length < 5 ||
          bytes.length > 50 * 1024 * 1024 ||
          String.fromCharCodes(bytes.take(5)) != '%PDF-') {
        throw const OperatorContractFailure('document_integrity');
      }
      return bytes;
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<void> renewSession() async {
    if (!await _client.renewCurrentSession()) {
      throw const OperatorContractFailure('session_refresh');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Object input) async {
    try {
      return _map(
        (await _client.dio.post<dynamic>(
          path,
          data: input,
          options: input is FormData
              ? Options(contentType: Headers.multipartFormDataContentType)
              : null,
        )).data,
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const OperatorContractFailure('invalid_response');
    }
    return value['data'] is Map<String, dynamic>
        ? value['data'] as Map<String, dynamic>
        : value;
  }

  static OperatorContractFailure _failure(DioException error) {
    final data = error.response?.data;
    final code = data is Map && data['errorCode'] is String
        ? data['errorCode'] as String
        : 'unavailable';
    return OperatorContractFailure(
      error.response == null ? 'network' : code,
      statusCode: error.response?.statusCode,
    );
  }
}
