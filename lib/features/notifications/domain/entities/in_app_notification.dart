import 'package:equatable/equatable.dart';

final class InAppNotification extends Equatable {
  const InAppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.relatedEntityType,
    required this.relatedEntityId,
    required this.createdAtUtc,
    required this.isRead,
  });

  final int id;
  final String type;
  final String? title;
  final String? body;
  final String? relatedEntityType;
  final int? relatedEntityId;
  final DateTime createdAtUtc;
  final bool isRead;

  InAppNotification markedRead() => InAppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    relatedEntityType: relatedEntityType,
    relatedEntityId: relatedEntityId,
    createdAtUtc: createdAtUtc,
    isRead: true,
  );

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    body,
    relatedEntityType,
    relatedEntityId,
    createdAtUtc,
    isRead,
  ];
}

final class InAppNotificationPage extends Equatable {
  const InAppNotificationPage({
    required this.items,
    required this.nextBeforeId,
  });

  final List<InAppNotification> items;
  final int? nextBeforeId;

  @override
  List<Object?> get props => [items, nextBeforeId];
}
