/// A UC-70 FCM data payload: identifiers only, and never business truth. The app
/// re-reads REST behind the usual guards before showing anything.
sealed class EmergencyPushHint {
  const EmergencyPushHint({required this.opened});

  /// The Traveler or Operator tapped the notification.
  final bool opened;

  /// Same logical notice, so a duplicate delivery can be dropped.
  String get dedupeKey;

  static EmergencyPushHint? tryParse(
    Map<String, dynamic> data, {
    required bool opened,
  }) => switch (data['type']) {
    'uc70_weather_safety_review' => _review(data, opened),
    'uc70_booking_emergency' => _booking(data, opened),
    _ => null,
  };

  static OperatorReviewHint? _review(Map<String, dynamic> data, bool opened) {
    final reviewId = _id(data['reviewId']);
    final changeType = data['changeType'];
    if (reviewId == null || changeType is! String) return null;
    return OperatorReviewHint(
      reviewId: reviewId,
      changeType: changeType,
      opened: opened,
    );
  }

  static TravelerBookingHint? _booking(Map<String, dynamic> data, bool opened) {
    final bookingId = _id(data['bookingId']);
    if (bookingId == null) return null;
    return TravelerBookingHint(
      bookingId: bookingId,
      operationId: _id(data['operationId']),
      opened: opened,
    );
  }

  static int? _id(Object? value) {
    final id = int.tryParse('$value');
    return id != null && id > 0 ? id : null;
  }
}

final class OperatorReviewHint extends EmergencyPushHint {
  const OperatorReviewHint({
    required this.reviewId,
    required this.changeType,
    required super.opened,
  });

  final int reviewId;

  /// Backend text: `Created` or `Escalated`.
  final String changeType;

  @override
  String get dedupeKey => 'review:$reviewId:$changeType:$opened';
}

final class TravelerBookingHint extends EmergencyPushHint {
  const TravelerBookingHint({
    required this.bookingId,
    required this.operationId,
    required super.opened,
  });

  final int bookingId;
  final int? operationId;

  @override
  String get dedupeKey => 'booking:$bookingId:$operationId:$opened';
}
