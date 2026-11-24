import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_contracts/data/models/operator_contract_dto.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/entities/operator_contract.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/repositories/operator_contract_repository.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/cubit/operator_contract_cubit.dart';
import 'operator_contract_dto_test.dart' show contractPayload;

final class _Repository implements OperatorContractRepository {
  OperatorContract value = OperatorContractDto.fromJson(
    contractPayload(),
  ).toDomain();
  final submissions = <ContractSignatureSubmission>[];
  OperatorContractFailure? signFailure;
  bool recoverSigned = false;
  @override
  Future<OperatorContract?> current() async => recoverSigned
      ? OperatorContractDto.fromJson(
          contractPayload(status: 'Signed'),
        ).toDomain()
      : value;
  @override
  Future<Uint8List> document(OperatorContract contract) async =>
      Uint8List.fromList('%PDF-test'.codeUnits);
  @override
  Future<OperatorContract> prepare(
    OperatorContract contract, {
    required String signerName,
    required String signerTitle,
    required String signerCapacity,
  }) async => value;
  @override
  Future<void> renewSession() async {}
  @override
  Future<ContractSigningChallenge> requestChallenge(
    OperatorContract contract,
  ) async => ContractSigningChallenge(
    id: 'challenge',
    expiresAtUtc: DateTime.utc(2026, 11, 24, 0, 3),
    resendAtUtc: DateTime.utc(2026, 11, 24, 0, 1),
    rowVersion: 'Ag==',
    maskedEmail: 'o***@example.test',
  );
  @override
  Future<OperatorContract> sign(
    OperatorContract contract,
    ContractSignatureSubmission submission,
  ) async {
    submissions.add(submission);
    if (signFailure case final error?) throw error;
    return OperatorContractDto.fromJson(
      contractPayload(status: 'Signed'),
    ).toDomain();
  }
}

void main() {
  final png = Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...List.filled(40, 1),
  ]);
  OperatorContractCubit subject(_Repository repository) =>
      OperatorContractCubit(repository, now: () => DateTime.utc(2026, 11, 24));
  Future<void> ready(OperatorContractCubit cubit) async {
    await cubit.load();
    await cubit.openDocument();
    cubit.markDocumentReviewed();
    cubit.setConsent(true);
    cubit.setSignature(png);
    await cubit.requestOtp();
  }

  test(
    'OTP cannot be requested until PDF is loaded, reviewed and signature is drawn',
    () async {
      final cubit = subject(_Repository());
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.requestOtp();
      expect(cubit.state.challenge, isNull);
      expect(cubit.state.error, isNotNull);
    },
  );
  test(
    'same payload retry keeps idempotency key after lost response',
    () async {
      final repository = _Repository()
        ..signFailure = const OperatorContractFailure('network');
      final cubit = subject(repository);
      addTearDown(cubit.close);
      await ready(cubit);
      await cubit.submit('123456');
      await cubit.submit('123456');
      expect(repository.submissions.length, 2);
      expect(
        repository.submissions[0].idempotencyKey,
        repository.submissions[1].idempotencyKey,
      );
      expect(cubit.state.contract!.isSigned, isFalse);
    },
  );
  test('lost sign response is reconciled using server Signed record', () async {
    final repository = _Repository()
      ..signFailure = const OperatorContractFailure('network');
    final cubit = subject(repository);
    addTearDown(cubit.close);
    await ready(cubit);
    repository.recoverSigned = true;
    await cubit.submit('123456');
    expect(cubit.state.contract!.isSigned, isTrue);
    expect(cubit.state.signature, isNull);
    expect(cubit.state.sessionRenewed, isTrue);
  });
  test(
    'revision conflict clears signature, consent, OTP and reviewed PDF',
    () async {
      final repository = _Repository()
        ..signFailure = const OperatorContractFailure(
          'contract.state_conflict',
          statusCode: 409,
        );
      final cubit = subject(repository);
      addTearDown(cubit.close);
      await ready(cubit);
      await cubit.submit('123456');
      expect(cubit.state.signature, isNull);
      expect(cubit.state.challenge, isNull);
      expect(cubit.state.consent, isFalse);
      expect(cubit.state.documentReviewed, isFalse);
    },
  );
  test(
    'five rejected OTP attempts stop local resubmission while preserving resend cooldown',
    () async {
      final repository = _Repository()
        ..signFailure = const OperatorContractFailure(
          'contract.otp_invalid',
          statusCode: 400,
        );
      final cubit = subject(repository);
      addTearDown(cubit.close);
      await ready(cubit);
      for (var attempt = 0; attempt < 6; attempt++) {
        await cubit.submit('123456');
      }
      expect(repository.submissions.length, 5);
      expect(cubit.state.challengeExhausted, isTrue);
      expect(cubit.canRequestOtp, isFalse);
      expect(cubit.state.challenge, isNotNull);
    },
  );
}
