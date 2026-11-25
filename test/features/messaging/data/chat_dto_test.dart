import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/messaging/data/models/chat_dto.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';

Map<String, Object?> groupMessage() => {
  'messageId': 90,
  'groupId': 7,
  'senderUserId': 42,
  'senderName': 'Sender',
  'senderAvatarUrl': null,
  'messageType': 'poll',
  'content': 'Where?',
  'metadataJson': jsonEncode({
    'options': [
      {'text': 'Here'},
      {'text': 'There'},
    ],
  }),
  'createdAtUtc': '2026-11-24T00:00:00Z',
  'readByCount': 0,
  'isReadByMe': false,
  'presentCount': 0,
  'isPresentByMe': false,
  'paidUserIds': <int>[],
  'pollVoteCounts': {'0': 2},
  'myPollVoteOption': 0,
  'clientMessageId': null,
};

void main() {
  const ref = ChatThreadRef(kind: ChatKind.group, id: 7);
  test('group DTO maps typed zero-based votes and immutable collections', () {
    final m = ChatMessageDto.fromJson(groupMessage(), ref).toDomain();
    expect(m.metadata!.pollOptions, ['Here', 'There']);
    expect(m.groupState!.pollVoteCounts, {0: 2});
    expect(m.groupState!.myPollVoteOption, 0);
    expect(() => m.groupState!.paidUserIds.add(99), throwsUnsupportedError);
  });
  test('rejects null, wrong identity, unknown type and malformed counters', () {
    for (final value in [
      null,
      [],
      {...groupMessage(), 'groupId': 8},
      {...groupMessage(), 'messageType': 'future_type'},
      {...groupMessage(), 'isReadByMe': 'false'},
      {
        ...groupMessage(),
        'pollVoteCounts': {'-1': 1},
      },
      {...groupMessage(), 'myPollVoteOption': 2},
      {...groupMessage(), 'metadataJson': '[]'},
      {...groupMessage(), 'createdAtUtc': 'yesterday'},
    ]) {
      expect(() => ChatMessageDto.fromJson(value, ref), throwsFormatException);
    }
  });
  test(
    'metadata serialization preserves FE participant and recipient contract',
    () {
      final m = ChatMetadata(
        title: 'Dinner',
        content: 'Details',
        totalAmountVnd: 101,
        bankCode: 'VCB',
        accountNumber: '12345678',
        accountName: 'Recipient',
        shares: const [
          ChatExpenseShare(userId: 42, displayName: 'Host', amountVnd: 51),
          ChatExpenseShare(userId: 43, displayName: 'Member', amountVnd: 50),
        ],
      );
      final json = ChatMetadataDto.encode(m);
      expect(jsonDecode(json)['participants'], [
        {'userId': 42, 'displayName': 'Host', 'amount': 51},
        {'userId': 43, 'displayName': 'Member', 'amount': 50},
      ]);
      expect(jsonDecode(json)['payerBankAccount'], '12345678');
      expect(jsonDecode(json)['content'], 'Details');
    },
  );
}
