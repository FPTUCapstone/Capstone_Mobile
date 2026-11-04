import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_realtime.dart';

/// The Operator's `/hubs/operator-weather-safety` hint connection. No logger is
/// attached: the hub URL carries the access token during connection setup.
final class SignalROperatorWeatherSafetyRealtime
    implements OperatorWeatherSafetyRealtime {
  SignalROperatorWeatherSafetyRealtime({
    required Uri apiBaseUrl,
    required SecureStorageService storage,
  }) : _apiBaseUrl = apiBaseUrl,
       _storage = storage;

  static const _clientEvent = 'WeatherSafetyReviewChanged';

  /// Bounded: when these run out the connection closes and the inbox polls.
  static const _reconnectDelaysMs = [0, 2000, 10000, 30000];

  final Uri _apiBaseUrl;
  final SecureStorageService _storage;
  final _hints = StreamController<WeatherSafetyReviewHint>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  HubConnection? _hub;

  static String hubUrl(Uri apiBaseUrl) => apiBaseUrl
      .replace(path: '/hubs/operator-weather-safety', query: null)
      .toString();

  /// The hub sends `{reviewId, tourScheduleId, changeType, occurredAtUtc}`.
  /// Anything else is dropped; a hint is never business truth anyway.
  static WeatherSafetyReviewHint? parseHint(List<Object?>? arguments) {
    final payload = arguments == null || arguments.isEmpty
        ? null
        : arguments.first;
    if (payload is! Map) return null;
    final reviewId = payload['reviewId'];
    final changeType = payload['changeType'];
    final occurredAt = payload['occurredAtUtc'];
    final occurredAtUtc = occurredAt is String
        ? DateTime.tryParse(occurredAt)?.toUtc()
        : null;
    if (reviewId is! int || changeType is! String || occurredAtUtc == null) {
      return null;
    }
    return WeatherSafetyReviewHint(
      reviewId: reviewId,
      changeType: changeType,
      occurredAtUtc: occurredAtUtc,
    );
  }

  @override
  Stream<WeatherSafetyReviewHint> get hints => _hints.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  Future<void> start() async {
    if (_hub != null) return;
    final hub = HubConnectionBuilder()
        .withUrl(
          hubUrl(_apiBaseUrl),
          options: HttpConnectionOptions(accessTokenFactory: _accessToken),
        )
        .withAutomaticReconnect(retryDelays: _reconnectDelaysMs)
        .build();
    _hub = hub;
    hub
      ..on(_clientEvent, (arguments) {
        final hint = parseHint(arguments);
        if (hint != null) _hints.add(hint);
      })
      ..onreconnecting(({error}) => _report(hub, false))
      ..onreconnected(({connectionId}) => _report(hub, true))
      ..onclose(({error}) {
        _report(hub, false);
        // Lets the next foreground start build a new connection.
        if (identical(_hub, hub)) _hub = null;
      });
    try {
      await hub.start();
      _report(hub, true);
    } on Object {
      if (identical(_hub, hub)) _hub = null;
      rethrow;
    }
  }

  void _report(HubConnection hub, bool connected) {
    if (identical(_hub, hub)) _connection.add(connected);
  }

  Future<String> _accessToken() async {
    final token = await _storage.read(AppConstants.accessTokenKey);
    if (token == null || token.isEmpty) {
      throw StateError('No signed-in session.');
    }
    return token;
  }

  @override
  Future<void> stop() async {
    final hub = _hub;
    _hub = null;
    await hub?.stop();
  }
}
