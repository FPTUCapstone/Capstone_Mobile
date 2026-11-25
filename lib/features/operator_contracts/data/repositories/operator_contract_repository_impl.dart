import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:trip_mate_mobile/features/operator_contracts/data/datasources/operator_contract_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_contracts/data/models/operator_contract_dto.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/entities/operator_contract.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/repositories/operator_contract_repository.dart';

final class OperatorContractRepositoryImpl
    implements OperatorContractRepository {
  const OperatorContractRepositoryImpl(this._remote);
  final OperatorContractRemoteDataSource _remote;
  @override
  Future<OperatorContract?> current() async {
    final value = await _remote.current();
    return value == null ? null : _parse(value);
  }

  @override
  Future<OperatorContract> prepare(
    OperatorContract contract, {
    required String signerName,
    required String signerTitle,
    required String signerCapacity,
  }) async => _parse(
    await _remote.prepare(contract.id, {
      'signerName': signerName,
      'signerTitle': signerTitle,
      'signerCapacity': signerCapacity,
      'rowVersion': contract.rowVersion,
    }),
  );
  @override
  Future<ContractSigningChallenge> requestChallenge(
    OperatorContract contract,
  ) async {
    try {
      return OperatorContractDto.challenge(
        await _remote.challenge(contract.id, {
          'expectedContentSha256': contract.acceptedContentSha256,
          'rowVersion': contract.rowVersion,
        }),
      );
    } on FormatException {
      throw const OperatorContractFailure('invalid_response');
    } on TypeError {
      throw const OperatorContractFailure('invalid_response');
    }
  }

  @override
  Future<OperatorContract> sign(
    OperatorContract contract,
    ContractSignatureSubmission submission,
  ) async => _parse(await _remote.sign(contract.id, submission));
  @override
  Future<Uint8List> document(OperatorContract contract) async {
    final bytes = await _remote.document(contract.id, contract.isSigned);
    final hash = contract.isSigned
        ? contract.signedDocumentSha256
        : contract.unsignedDocumentSha256;
    if (hash == null || sha256.convert(bytes).toString() != hash) {
      throw const OperatorContractFailure('document_integrity');
    }
    return bytes;
  }

  @override
  Future<void> renewSession() => _remote.renewSession();
  static OperatorContract _parse(Map<String, dynamic> data) {
    try {
      return OperatorContractDto.fromJson(data).toDomain();
    } on FormatException {
      throw const OperatorContractFailure('invalid_response');
    } on TypeError {
      throw const OperatorContractFailure('invalid_response');
    }
  }
}
