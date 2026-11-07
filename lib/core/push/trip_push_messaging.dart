import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:trip_mate_mobile/core/push/emergency_push_hint.dart';

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

  /// Shows the system prompt.
  Future<bool> requestPermission();

  /// Reads the current permission without prompting.
  Future<bool> hasPermission();
  Future<String?> getToken();
  Future<TripPushHint?> getInitialHint();
}

abstract interface class EmergencyPushMessaging {
  Stream<EmergencyPushHint> get foregroundEmergencyHints;
  Stream<EmergencyPushHint> get openedEmergencyHints;

  Future<EmergencyPushHint?> getInitialEmergencyHint();
}

final class FirebaseTripPushMessaging
    implements TripPushMessaging, EmergencyPushMessaging {
  FirebaseTripPushMessaging(this._messaging);

  final FirebaseMessaging _messaging;
  Future<RemoteMessage?>? _initialMessage;
  bool _initialEmergencyRead = false;

  /// The plugin answers getInitialMessage once, so every reader shares this read.
  Future<RemoteMessage?> _readInitialMessage() =>
      _initialMessage ??= _messaging.getInitialMessage();

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
  Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Stream<EmergencyPushHint> get foregroundEmergencyHints =>
      _emergency(FirebaseMessaging.onMessage, opened: false);

  @override
  Stream<EmergencyPushHint> get openedEmergencyHints =>
      _emergency(FirebaseMessaging.onMessageOpenedApp, opened: true);

  @override
  Future<EmergencyPushHint?> getInitialEmergencyHint() async {
    // Once only: a later sign-in on this process must not replay the old tap.
    if (_initialEmergencyRead) return null;
    _initialEmergencyRead = true;
    final message = await _readInitialMessage();
    return message == null
        ? null
        : EmergencyPushHint.tryParse(message.data, opened: true);
  }

  static Stream<EmergencyPushHint> _emergency(
    Stream<RemoteMessage> messages, {
    required bool opened,
  }) => messages
      .map(
        (message) => EmergencyPushHint.tryParse(message.data, opened: opened),
      )
      .where((hint) => hint != null)
      .cast<EmergencyPushHint>();

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<TripPushHint?> getInitialHint() async {
    final message = await _readInitialMessage();
    if (message == null) return null;
    final hint = TripPushHint.fromData(message.data, opened: true);
    return hint.isValid ? hint : null;
  }
}
