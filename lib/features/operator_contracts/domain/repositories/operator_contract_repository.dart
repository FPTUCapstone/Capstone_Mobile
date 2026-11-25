import 'dart:typed_data';
import 'package:trip_mate_mobile/features/operator_contracts/domain/entities/operator_contract.dart';

abstract interface class OperatorContractRepository {
  Future<OperatorContract?> current();
  Future<OperatorContract> prepare(
    OperatorContract contract, {
    required String signerName,
    required String signerTitle,
    required String signerCapacity,
  });
  Future<Uint8List> document(OperatorContract contract);
  Future<ContractSigningChallenge> requestChallenge(OperatorContract contract);
  Future<OperatorContract> sign(
    OperatorContract contract,
    ContractSignatureSubmission submission,
  );
  Future<void> renewSession();
}
