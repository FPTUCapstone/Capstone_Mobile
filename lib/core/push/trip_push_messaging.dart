import 'package:firebase_messaging/firebase_messaging.dart';

final class TripPushHint {
  const TripPushHint({
    required this.sessionId,
    required this.incidentId,
    required this.opened,
  });

  factory TripPushHint.fromData(
    Map<String, dynamic> data, {
    required bool opened,
  }) {
    return TripPushHint(
      sessionId: int.tryParse('${data['sessionId']}'),
      incidentId: int.tryParse('${data['incidentId']}'),
      opened: opened,
    );
  }

  final int? sessionId;
  final int? incidentId;
  final bool opened;

  bool get isValid => sessionId != null && incidentId != null;
}

abstract interface class TripPushMessaging {
  Stream<String> get tokenRefreshes;
  Stream<TripPushHint> get foregroundHints;
  Stream<TripPushHint> get openedHints;

  Future<bool> requestPermission();
  Future<String?> getToken();
  Future<TripPushHint?> getInitialHint();
}

final class FirebaseTripPushMessaging implements TripPushMessaging {
  FirebaseTripPushMessaging(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<TripPushHint> get foregroundHints => FirebaseMessaging.onMessage
      .map((message) => TripPushHint.fromData(message.data, opened: false))
      .where((hint) => hint.isValid);

  @override
  Stream<TripPushHint> get openedHints => FirebaseMessaging.onMessageOpenedApp
      .map((message) => TripPushHint.fromData(message.data, opened: true))
      .where((hint) => hint.isValid);

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<TripPushHint?> getInitialHint() async {
    final message = await _messaging.getInitialMessage();
    if (message == null) return null;
    final hint = TripPushHint.fromData(message.data, opened: true);
    return hint.isValid ? hint : null;
  }
}
