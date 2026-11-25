import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/notifications/domain/entities/in_app_notification.dart';

String? travelerNotificationDestination(InAppNotification item) =>
    item.relatedEntityType == 'Booking' ? AppRoutes.tripHistory : null;

String? operatorNotificationDestination(InAppNotification item) {
  final tourId = item.relatedEntityId;
  if (item.type == 'TourApproved' &&
      item.relatedEntityType == 'Tour' &&
      tourId != null &&
      tourId > 0) {
    return AppRoutes.editTourPackagePath(tourId);
  }
  return null;
}
