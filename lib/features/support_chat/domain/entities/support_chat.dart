import 'package:equatable/equatable.dart';

final class SupportChatContext extends Equatable {
  const SupportChatContext({required this.kind, required this.id});

  final String kind;
  final String id;

  bool get isValid {
    if ((kind != 'refund' && kind != 'itinerary' && kind != 'tour') ||
        !RegExp(r'^[0-9]+$').hasMatch(id)) {
      return false;
    }
    final normalized = id.replaceFirst(RegExp(r'^0+'), '');
    return normalized.isNotEmpty &&
        (normalized.length < 19 ||
            (normalized.length == 19 &&
                normalized.compareTo('9223372036854775807') <= 0));
  }

  @override
  List<Object?> get props => [kind, id];
}

final class SupportChatSource {
  const SupportChatSource({
    required this.id,
    required this.title,
    required this.url,
  });

  final String id;
  final String title;
  final String url;
}

final class SupportChatMessage {
  const SupportChatMessage({
    required this.role,
    required this.content,
    this.sources = const [],
    this.actions = const [],
  });

  final String role;
  final String content;
  final List<SupportChatSource> sources;
  final List<SupportChatAction> actions;
}

final class SupportChatReply {
  const SupportChatReply({
    required this.answer,
    required this.sources,
    this.context,
    this.actions = const [],
  });

  final String answer;
  final List<SupportChatSource> sources;
  final SupportChatContext? context;
  final List<SupportChatAction> actions;
}

enum SupportChatActionType { navigate, selectContext }

final class SupportChatAction {
  const SupportChatAction({
    required this.type,
    required this.label,
    this.url,
    this.prompt,
    this.description,
    this.context,
  });

  final SupportChatActionType type;
  final String label;
  final String? url;
  final String? prompt;
  final String? description;
  final SupportChatContext? context;
}
