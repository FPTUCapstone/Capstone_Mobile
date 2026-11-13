import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/support_chat/data/models/support_chat_response_model.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';

void main() {
  test('defaults absent or null response actions to an empty list', () {
    for (final json in [
      <String, dynamic>{'answer': 'How can I help?', 'sources': const []},
      <String, dynamic>{
        'answer': 'How can I help?',
        'sources': const [],
        'actions': null,
      },
    ]) {
      final reply = SupportChatResponseModel.fromJson(json).toDomain();

      expect(reply.actions, isEmpty);
    }
  });

  test('parses navigation and context-selection actions', () {
    final reply = SupportChatResponseModel.fromJson({
      'answer': 'How can I help?',
      'sources': const [],
      'actions': [
        {
          'type': 'navigate',
          'label': 'Open refund status',
          'url': '/refunds/42',
          'description': 'See the latest status.',
          'backendExtension': true,
        },
        {
          'type': 'selectContext',
          'label': 'Ask about this tour',
          'context': {'kind': 'tour', 'id': '00042'},
          'prompt': 'Can you explain this tour?',
        },
      ],
    }).toDomain();

    expect(reply.actions, hasLength(2));
    expect(reply.actions.first.type, SupportChatActionType.navigate);
    expect(reply.actions.first.url, '/refunds/42');
    expect(reply.actions.first.description, 'See the latest status.');
    expect(reply.actions.last.type, SupportChatActionType.selectContext);
    expect(
      reply.actions.last.context,
      const SupportChatContext(kind: 'tour', id: '00042'),
    );
    expect(reply.actions.last.prompt, 'Can you explain this tour?');
  });

  test('rejects malformed actions with a FormatException', () {
    const validContext = {'kind': 'tour', 'id': '42'};
    final invalidActions = <Object?>[
      'not a list',
      [null],
      [<String, dynamic>{}],
      [
        {'type': 1, 'label': 'Open', 'url': '/refunds/42'},
      ],
      [
        {'type': 'unknown', 'label': 'Open', 'url': '/refunds/42'},
      ],
      [
        {'type': 'navigate', 'label': 1, 'url': '/refunds/42'},
      ],
      [
        {'type': 'navigate', 'label': 'Open'},
      ],
      [
        {'type': 'navigate', 'label': 'Open', 'url': 1},
      ],
      [
        {
          'type': 'navigate',
          'label': 'Open',
          'url': '/refunds/42',
          'description': 1,
        },
      ],
      [
        {'type': 'selectContext', 'label': 'Select', 'prompt': 'Help'},
      ],
      [
        {'type': 'selectContext', 'label': 'Select', 'context': validContext},
      ],
      [
        {
          'type': 'selectContext',
          'label': 'Select',
          'context': validContext,
          'prompt': '',
        },
      ],
      [
        {
          'type': 'selectContext',
          'label': 'Select',
          'context': {'kind': 'tour', 'id': '0'},
          'prompt': 'Help',
        },
      ],
      [
        {
          'type': 'selectContext',
          'label': 'Select',
          'context': {'kind': 'tour', 'id': '9223372036854775808'},
          'prompt': 'Help',
        },
      ],
      [
        {
          'type': 'selectContext',
          'label': 'Select',
          'context': validContext,
          'prompt': 'a' * 2001,
        },
      ],
    ];

    for (final actions in invalidActions) {
      expect(
        () => SupportChatResponseModel.fromJson({
          'answer': 'How can I help?',
          'sources': const [],
          'actions': actions,
        }),
        throwsFormatException,
      );
    }
  });

  test('accepts omitted and null inactive variant fields', () {
    final reply = SupportChatResponseModel.fromJson({
      'answer': 'Choose a next step',
      'sources': [],
      'actions': [
        {
          'type': 'navigate',
          'label': 'Tours',
          'url': '/tours',
          'context': null,
          'prompt': null,
          'description': null,
        },
        {
          'type': 'selectContext',
          'label': 'Tour',
          'context': {'kind': 'tour', 'id': '7'},
          'prompt': 'Show tour',
          'url': null,
        },
      ],
    }).toDomain();
    expect(reply.actions, hasLength(2));
  });

  test('rejects conflicting non-null action variant fields', () {
    for (final action in [
      {
        'type': 'navigate',
        'label': 'Tours',
        'url': '/tours',
        'context': {'kind': 'tour', 'id': '7'},
      },
      {
        'type': 'navigate',
        'label': 'Tours',
        'url': '/tours',
        'prompt': 'Show tours',
      },
      {
        'type': 'selectContext',
        'label': 'Tour',
        'context': {'kind': 'tour', 'id': '7'},
        'prompt': 'Show tour',
        'url': '/tours/7',
      },
    ]) {
      expect(
        () => SupportChatResponseModel.fromJson({
          'answer': 'Help',
          'sources': [],
          'actions': [action],
        }),
        throwsFormatException,
      );
    }
  });
}
