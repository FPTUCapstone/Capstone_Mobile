import 'package:trip_mate_mobile/features/traveler/domain/entities/in_app_notification.dart';

abstract interface class InAppNotificationRepository {
  Future<InAppNotificationPage> getInbox({
    bool unreadOnly = false,
    int limit = 20,
    int? beforeId,
  });

  Future<void> markRead(int notificationId);
}
