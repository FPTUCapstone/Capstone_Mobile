import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';

final class SupportChatResponseModel {
  const SupportChatResponseModel._(
    this.answer,
    this.sources,
    this.kind,
    this.contextId,
    this.actions,
  );

  factory SupportChatResponseModel.fromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['sources'] is! List) {
      throw const FormatException('Invalid support response.');
    }
    final sources = <({String id, String title, String url})>[];
    for (final source in json['sources'] as List) {
      if (source is! Map<String, dynamic>) {
        throw const FormatException('Invalid support source.');
      }
      sources.add((
        id: _text(source['id']),
        title: _text(source['title']),
        url: _text(source['url']),
      ));
    }
    String? kind;
    String? id;
    if (json['context'] case final Object context) {
      final parsedContext = _context(context);
      kind = parsedContext.kind;
      id = parsedContext.id;
    }
    return SupportChatResponseModel._(
      _text(json['answer']),
      List.unmodifiable(sources),
      kind,
      id,
      _actions(json['actions']),
    );
  }

  final String answer;
  final List<({String id, String title, String url})> sources;
  final String? kind;
  final String? contextId;
  final List<SupportChatAction> actions;

  SupportChatReply toDomain() => SupportChatReply(
    answer: answer,
    sources: List.unmodifiable(
      sources.map(
        (source) => SupportChatSource(
          id: source.id,
          title: source.title,
          url: source.url,
        ),
      ),
    ),
    context: switch ((kind, contextId)) {
      (final String kind, final String id) => SupportChatContext(
        kind: kind,
        id: id,
      ),
      _ => null,
    },
    actions: actions,
  );

  static List<SupportChatAction> _actions(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('Invalid support actions.');
    }
    return List.unmodifiable(
      value.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Invalid support action.');
        }
        final type = switch (_text(entry['type'])) {
          'navigate' => SupportChatActionType.navigate,
          'selectContext' => SupportChatActionType.selectContext,
          _ => throw const FormatException('Invalid support action type.'),
        };
        final url = _optionalText(entry['url']);
        final prompt = _optionalText(entry['prompt']);
        final description = _optionalText(entry['description']);
        final context = switch (entry['context']) {
          null => null,
          final Object value => _context(value),
        };
        if (type == SupportChatActionType.navigate &&
            (url == null || context != null || prompt != null)) {
          throw const FormatException('Invalid navigation action.');
        }
        if (type == SupportChatActionType.selectContext &&
            (context == null ||
                prompt == null ||
                !_isValidPrompt(prompt) ||
                url != null)) {
          throw const FormatException('Invalid context action.');
        }
        return SupportChatAction(
          type: type,
          label: _text(entry['label']),
          url: url,
          prompt: prompt,
          description: description,
          context: context,
        );
      }),
    );
  }

  static SupportChatContext _context(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid support context.');
    }
    final context = SupportChatContext(
      kind: _text(value['kind']),
      id: _text(value['id']),
    );
    if (!context.isValid) {
      throw const FormatException('Invalid support context.');
    }
    return context;
  }

  static String? _optionalText(Object? value) => switch (value) {
    null => null,
    _ => _text(value),
  };

  static bool _isValidPrompt(String value) =>
      value.trim().isNotEmpty && value.length <= 2000;

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid support text.');
    }
    return value;
  }
}
