import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_realtime.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_state.dart';

/// The Operator's Safety Alerts inbox, shared by the workspace badge and the
/// list page. REST is the only source of truth; realtime hints, resume and
/// reconnect just ask for a refresh.
final class OperatorSafetyReviewsCubit
    extends Cubit<OperatorSafetyReviewsState> {
  OperatorSafetyReviewsCubit({
    required GetWeatherSafetyReviewsUseCase getReviews,
    required NetworkInfo networkInfo,
    required OperatorWeatherSafetyRealtime realtime,
  }) : _getReviews = getReviews,
       _networkInfo = networkInfo,
       _realtime = realtime,
       super(const OperatorSafetyReviewsState());

  static const pollInterval = Duration(seconds: 30);

  final GetWeatherSafetyReviewsUseCase _getReviews;
  final NetworkInfo _networkInfo;
  final OperatorWeatherSafetyRealtime _realtime;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _seenHints = <WeatherSafetyReviewHint>{};
  Future<void>? _inFlight;
  bool _refreshAgain = false;
  bool _realtimeConnected = true;
  bool _inboxVisible = false;
  bool _inForeground = true;
  Timer? _pollTimer;

  /// Bumped by [reset] so a late response cannot restore another account's data.
  int _generation = 0;

  /// Starts the signed-in Operator's realtime connection and first load.
  Future<void> startSession() async {
    _listen();
    _inForeground = true;
    _startRealtime();
    await refresh();
  }

  /// At most one request runs at a time; requests made meanwhile collapse into
  /// a single follow-up, so a burst of hints cannot become a refresh storm.
  Future<void> refresh() {
    final running = _inFlight;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    final future = _load().whenComplete(() {
      _inFlight = null;
      if (_refreshAgain && !isClosed) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    });
    return _inFlight = future;
  }

  void setFilter(WeatherSafetyReviewStatus? filter) => emit(
    filter == null
        ? state.copyWith(clearFilter: true)
        : state.copyWith(filter: filter),
  );

  @visibleForTesting
  bool get isInboxVisible => _inboxVisible;

  void setInboxVisible(bool visible) {
    _inboxVisible = visible;
    _syncPolling();
  }

  Future<void> onBackground() async {
    _inForeground = false;
    _syncPolling();
    await _stopRealtime();
  }

  Future<void> onForeground() async {
    if (_inForeground) return;
    _inForeground = true;
    _startRealtime();
    await refresh();
  }

  /// Sign-out or account change: nothing from this session may survive.
  Future<void> reset() async {
    _generation++;
    _refreshAgain = false;
    _inboxVisible = false;
    _realtimeConnected = true;
    _seenHints.clear();
    _syncPolling();
    // Cleared first, so no awaited step below can leave old data on screen.
    if (!isClosed) emit(const OperatorSafetyReviewsState());
    await _stopRealtime();
    await _cancelSubscriptions();
  }

  Future<void> _load() async {
    if (isClosed) return;
    final generation = _generation;
    final hasData = state.reviews.isNotEmpty;
    if (!hasData) {
      emit(
        state.copyWith(
          status: OperatorSafetyReviewsStatus.loading,
          clearFailure: true,
        ),
      );
    }
    final connected = await _networkInfo.isConnected;
    if (_isOutdated(generation)) return;
    if (!connected) {
      _emitFailure(const NetworkFailure());
      return;
    }
    try {
      final reviews = await _getReviews();
      if (_isOutdated(generation)) return;
      emit(
        state.copyWith(
          status: OperatorSafetyReviewsStatus.ready,
          reviews: reviews,
          clearFailure: true,
          isStale: false,
        ),
      );
    } on Failure catch (failure) {
      if (!_isOutdated(generation)) _emitFailure(failure);
    }
  }

  void _emitFailure(Failure failure) {
    // A failed silent refresh keeps the list on screen, labelled as stale.
    final hasData = state.reviews.isNotEmpty;
    emit(
      state.copyWith(
        status: hasData
            ? OperatorSafetyReviewsStatus.ready
            : OperatorSafetyReviewsStatus.failure,
        failure: failure,
        isStale: hasData,
      ),
    );
  }

  bool _isOutdated(int generation) => isClosed || generation != _generation;

  void _listen() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(
        _realtime.hints.listen((hint) {
          if (_seenHints.add(hint)) unawaited(refresh());
        }),
      )
      ..add(
        _realtime.connection.listen((connected) {
          final recovered = connected && !_realtimeConnected;
          _realtimeConnected = connected;
          _syncPolling();
          if (recovered) unawaited(refresh());
        }),
      )
      ..add(
        _networkInfo.onConnectivityChanged.listen((connected) {
          if (connected) unawaited(refresh());
        }),
      );
  }

  void _startRealtime() {
    // Realtime is best effort: the inbox keeps working over REST without it.
    unawaited(
      _realtime.start().catchError((Object _) {
        if (isClosed) return;
        _realtimeConnected = false;
        _syncPolling();
      }),
    );
  }

  Future<void> _stopRealtime() async {
    try {
      await _realtime.stop();
    } on Object {
      // The connection is being discarded either way.
    }
  }

  void _syncPolling() {
    final shouldPoll = _inboxVisible && _inForeground && !_realtimeConnected;
    if (!shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
  }

  Future<void> _cancelSubscriptions() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  Future<void> close() async {
    _pollTimer?.cancel();
    await _cancelSubscriptions();
    await _stopRealtime();
    return super.close();
  }
}
