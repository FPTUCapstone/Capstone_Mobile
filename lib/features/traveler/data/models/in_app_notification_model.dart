import 'package:trip_mate_mobile/features/traveler/domain/entities/in_app_notification.dart';

final class InAppNotificationModel {
  const InAppNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.relatedEntityType,
    required this.relatedEntityId,
    required this.createdAtUtc,
    required this.isRead,
  });

  factory InAppNotificationModel.fromJson(Map<String, dynamic> json) =>
      InAppNotificationModel(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String,
        title: json['title'] as String?,
        body: json['body'] as String?,
        relatedEntityType: json['relatedEntityType'] as String?,
        relatedEntityId: (json['relatedEntityId'] as num?)?.toInt(),
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
        isRead: json['isRead'] as bool,
      );

  final int id;
  final String type;
  final String? title;
  final String? body;
  final String? relatedEntityType;
  final int? relatedEntityId;
  final DateTime createdAtUtc;
  final bool isRead;

  InAppNotification toEntity() => InAppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    relatedEntityType: relatedEntityType,
    relatedEntityId: relatedEntityId,
    createdAtUtc: createdAtUtc,
    isRead: isRead,
  );
}
