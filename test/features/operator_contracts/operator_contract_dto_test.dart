import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_contracts/data/models/operator_contract_dto.dart';

Map<String, dynamic> contractPayload({
  String status = 'PendingSignature',
  String documentState = 'Ready',
}) => {
  'id': '9007199254740993',
  'status': status,
  'documentState': documentState,
  'title': 'Hợp đồng',
  'templateVersion': 2,
  'companyName': 'Company',
  'taxCode': '0123456789',
  'businessLicenseNo': 'LIC',
  'businessAddress': 'Đà Nẵng',
  'operatorEmail': 'operator@example.test',
  'signerName': 'Nguyễn Văn A',
  'signerTitle': 'Giám đốc',
  'signerCapacity': 'Đại diện pháp luật',
  'acceptedContentSha256': 'a' * 64,
  'unsignedDocumentSha256': 'b' * 64,
  'signedDocumentSha256': status == 'Signed' ? 'c' * 64 : null,
  'rowVersion': 'AQ==',
  'canPrepare': false,
  'canSign': status == 'PendingSignature',
  'approvedAtUtc': '2026-11-24T00:00:00Z',
  'signedAtUtc': status == 'Signed' ? '2026-11-24T01:00:00Z' : null,
  'otpPolicy': {
    'timeToLiveSeconds': 180,
    'resendCooldownSeconds': 60,
    'maxFailedAttempts': 5,
    'consentVersion': 'operator-contract-v1',
  },
};

void main() {
  test('preserves opaque IDs and exact accepted content hash', () {
    final value = OperatorContractDto.fromJson(contractPayload()).toDomain();
    expect(value.id, '9007199254740993');
    expect(value.acceptedContentSha256, 'a' * 64);
    expect(value.canSign, isTrue);
    expect(value.otpPolicy.timeToLiveSeconds, 180);
  });
  test('unknown contract/document states fail closed', () {
    expect(
      () => OperatorContractDto.fromJson(
        contractPayload(status: 'Unknown'),
      ).toDomain(),
      throwsFormatException,
    );
    expect(
      () => OperatorContractDto.fromJson(
        contractPayload(documentState: 'Unknown'),
      ).toDomain(),
      throwsFormatException,
    );
  });
  test(
    'signed records never allow preparing or signing even if wire flags disagree',
    () {
      final value = OperatorContractDto.fromJson({
        ...contractPayload(status: 'Signed'),
        'canSign': true,
        'canPrepare': true,
      }).toDomain();
      expect(value.canSign, isFalse);
      expect(value.canPrepare, isFalse);
    },
  );
}
