import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/core/push/trip_push_messaging.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/weather_advisory.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/trip_alert_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/arrival_detector.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/geo_distance.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/route_progress_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/weather_advisory_session_store.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:uuid/uuid.dart';

/// UC-13 live navigation. The Backend session records progress; GPS, arrival
/// detection, guidance, and deviation stay on the device.
class ActiveTripCubit extends Cubit<ActiveTripState> {
  ActiveTripCubit({
    required int itineraryId,
    required NavigationSessionRepository sessionRepository,
    NavigationLocationTracker? locationTracker,
    RouteDirectionsRepository? directionsRepository,
    ItineraryRepository? itineraryRepository,
    String itineraryTitle = 'Active Trip',
    List<TripAlert>? initialAlerts,
    bool isDemoMode = false,
    ArrivalDetector? arrivalDetector,
    DateTime Function()? clock,
    String? idempotencyKey,
    NetworkInfo? networkInfo,
    TripAlertRepository? alertRepository,
    Stream<TripPushHint>? pushHints,
    WeatherAdvisorySessionStore? weatherAdvisoryStore,
  }) : _sessionRepository = sessionRepository,
       _networkInfo = networkInfo,
       _alertRepository = alertRepository,
       _weatherAdvisoryStore =
           weatherAdvisoryStore ?? WeatherAdvisorySessionStore(),
       _locationTracker = locationTracker,
       _directionsRepository = directionsRepository,
       _itineraryRepository = itineraryRepository,
       _arrivalDetector = arrivalDetector ?? ArrivalDetector(),
       _clock = clock ?? DateTime.now,
       _idempotencyKey = idempotencyKey ?? const Uuid().v4(),
       super(
         _initialState(
           itineraryId: itineraryId,
           itineraryTitle: itineraryTitle,
           initialAlerts: initialAlerts,
           isDemoMode: isDemoMode,
           isGuidanceAvailable: directionsRepository?.isAvailable ?? false,
         ),
       ) {
    _pushHintSubscription = pushHints?.listen((hint) {
      if (hint.sessionId == state.session?.sessionId) {
        unawaited(refreshAlerts());
      }
    });
  }

  static const offRouteThresholdMeters = 60.0;
  static const offRouteConsecutiveFixes = 3;
  static const maxAccuracyAllowanceMeters = 30.0;
  static const routeRequestCooldown = Duration(seconds: 30);
  static const arrivalReevaluationInterval = Duration(seconds: 5);

  final NavigationSessionRepository _sessionRepository;
  final NavigationLocationTracker? _locationTracker;
  final RouteDirectionsRepository? _directionsRepository;
  final ItineraryRepository? _itineraryRepository;
  final ArrivalDetector _arrivalDetector;
  final DateTime Function() _clock;
  final NetworkInfo? _networkInfo;
  final TripAlertRepository? _alertRepository;
  final WeatherAdvisorySessionStore _weatherAdvisoryStore;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<TripPushHint>? _pushHintSubscription;

  /// Set while another confirmation dialog is open, so an arrival question
  /// never stacks on top of it.
  bool _arrivalPromptsPaused = false;

  /// The last progress action that failed for a transport reason.
  Future<void> Function()? _retryAction;

  static const offlineMessage =
      'You are offline. Check your connection and try again.';

  /// One key per page instance so retried starts replay the same session.
  final String _idempotencyKey;

  StreamSubscription<NavigationPosition>? _positionSubscription;
  Timer? _arrivalTimer;
  NavigationPosition? _lastPosition;
  RouteProgressTracker? _routeTracker;
  int? _routeTargetItemId;
  bool _isRouteLoading = false;
  DateTime? _lastRouteRequestAt;
  int? _lastRouteRequestTargetId;
  int _trackingGeneration = 0;
  int _offRouteFixes = 0;
  DateTime? _arrivalDetectedAt;
  int _feedbackId = 0;
  int _alertRefreshGeneration = 0;

  static ActiveTripState _initialState({
    required int itineraryId,
    required String itineraryTitle,
    required List<TripAlert>? initialAlerts,
    required bool isDemoMode,
    required bool isGuidanceAvailable,
  }) {
    final alerts =
        initialAlerts ??
        (isDemoMode ? ActiveTripDemoFixtures.createSampleAlerts() : const []);
    return ActiveTripState(
      itineraryId: itineraryId,
      itineraryTitle: itineraryTitle,
      alerts: alerts,
      activeBannerAlert: alerts.cast<TripAlert?>().firstWhere(
        (alert) => alert != null && !alert.isDismissedFromBanner,
        orElse: () => null,
      ),
      isGuidanceAvailable: isGuidanceAvailable,
      isDemoMode: isDemoMode,
    );
  }

  // ───────────────────────── Session lifecycle ───────────────────────── //

  /// Starts navigation, or resumes the Traveler's open session for this
  /// itinerary.
  Future<void> start() async {
    if (state.loadStatus == ActiveTripLoadStatus.ready) return;
    _watchConnectivity();
    _emit(
      state.copyWith(
        loadStatus: ActiveTripLoadStatus.loading,
        clearLoadError: true,
        canRetryLoad: true,
        clearConflictSession: true,
      ),
    );

    try {
      final session = await _sessionRepository.start(
        itineraryId: state.itineraryId,
        idempotencyKey: _idempotencyKey,
      );
      _onSessionLoaded(session);
    } on NavigationFailure catch (failure) {
      if (failure.reason == NavigationFailureReason.activeSessionExists &&
          failure.activeSessionId != null) {
        await _handleExistingSession(failure.activeSessionId!);
        return;
      }
      _failStart(
        failure.message,
        canRetry: !_permanentStartFailures.contains(failure.reason),
      );
    } on Failure catch (failure) {
      _failStart(failure.message);
    }
  }

  Future<void> _handleExistingSession(int sessionId) async {
    try {
      final existing = await _sessionRepository.getById(sessionId);
      if (await _isSameTrip(existing)) {
        _onSessionLoaded(existing, resumed: true);
      } else {
        _emit(
          state.copyWith(
            loadStatus: ActiveTripLoadStatus.conflict,
            conflictSession: existing,
            conflictSessionId: sessionId,
          ),
        );
      }
    } on NavigationFailure catch (failure) {
      // The Traveler may have lost access to the other trip (e.g. removed
      // from the group); its owner can still end it, so offer that.
      if (failure.reason == NavigationFailureReason.accessDenied) {
        _emit(
          state.copyWith(
            loadStatus: ActiveTripLoadStatus.conflict,
            conflictSessionId: sessionId,
          ),
        );
        return;
      }
      _failStart(failure.message);
    } on Failure catch (failure) {
      _failStart(failure.message);
    }
  }

  /// The session stores the itinerary version resolved at start, which may
  /// differ from the id this page was opened with; versions of one trip share
  /// the scheduling request.
  Future<bool> _isSameTrip(NavigationSession existing) async {
    if (existing.itineraryId == state.itineraryId) return true;
    final itineraries = _itineraryRepository;
    if (itineraries == null) return false;
    try {
      final requested = await itineraries.getById(state.itineraryId);
      final active = await itineraries.getById(existing.itineraryId);
      return requested.schedulingRequestId == active.schedulingRequestId;
    } catch (_) {
      return false;
    }
  }

  /// Closes the open session of another itinerary, then starts this one.
  Future<void> endConflictingSessionAndStart() async {
    final conflictId = state.conflictSessionId;
    if (conflictId == null || state.isSubmitting) return;
    _emit(state.copyWith(isSubmitting: true));
    try {
      await _sessionRepository.complete(conflictId);
      _emit(state.copyWith(isSubmitting: false));
      await start();
    } on Failure catch (failure) {
      _emit(
        state.copyWith(
          isSubmitting: false,
          feedback: _feedback(failure.message, isError: true),
        ),
      );
    }
  }

  /// Start rejections that a retry cannot change.
  static const _permanentStartFailures = {
    NavigationFailureReason.outsideTripWindow,
    NavigationFailureReason.itineraryNotActive,
    NavigationFailureReason.noNavigableItems,
    NavigationFailureReason.itineraryScheduleIncomplete,
    NavigationFailureReason.accessDenied,
  };

  void _failStart(String message, {bool canRetry = true}) {
    _emit(
      state.copyWith(
        loadStatus: ActiveTripLoadStatus.failed,
        loadErrorMessage: message,
        canRetryLoad: canRetry,
      ),
    );
  }

  void _onSessionLoaded(NavigationSession session, {bool resumed = false}) {
    _emit(
      state.copyWith(
        loadStatus: ActiveTripLoadStatus.ready,
        clearConflictSession: true,
        status: state.isDemoMode
            ? ActiveTripStatus.navigationActive
            : ActiveTripStatus.navigationInitial,
      ),
    );
    _applySession(
      session,
      feedback: resumed ? 'Resumed your trip in progress.' : null,
    );
    if (!state.isDemoMode) unawaited(refreshAlerts());
    if (!session.isCompleted) unawaited(_startTracking());
  }

  // ───────────────────────────── Location ───────────────────────────── //

  Future<void> _startTracking() async {
    final tracker = _locationTracker;
    if (tracker == null || state.isTerminal) return;
    final generation = ++_trackingGeneration;
    await _stopTracking();
    _emit(state.copyWith(status: ActiveTripStatus.navigationAcquiringPosition));

    final access = await tracker.ensureAccess();
    // A newer start, or a stop, superseded this attempt.
    if (isClosed || state.isTerminal || generation != _trackingGeneration) {
      return;
    }
    switch (access) {
      case NavigationLocationAccess.denied:
      case NavigationLocationAccess.deniedForever:
        _emit(
          state.copyWith(status: ActiveTripStatus.navigationPermissionDenied),
        );
        return;
      case NavigationLocationAccess.serviceDisabled:
        _emit(
          state.copyWith(
            status: ActiveTripStatus.navigationLocationServiceDisabled,
          ),
        );
        return;
      case NavigationLocationAccess.granted:
        break;
    }

    _positionSubscription = tracker.watchPosition().listen(
      updatePosition,
      onError: (Object _) {
        if (state.isTerminal) return;
        _emit(
          state.copyWith(
            status: ActiveTripStatus.navigationPositionUnavailable,
          ),
        );
      },
    );
    _arrivalTimer = Timer.periodic(arrivalReevaluationInterval, (_) {
      final last = _lastPosition;
      if (last != null) _detectArrival(last.coordinate, last.accuracyMeters);
    });
  }

  Future<void> _stopTracking({bool invalidate = false}) async {
    if (invalidate) _trackingGeneration++;
    _arrivalTimer?.cancel();
    _arrivalTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Retries location access after the Traveler fixed permissions/settings.
  Future<void> retryLocation() => _startTracking();

  Future<void> openLocationSettings() async {
    await _locationTracker?.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await _locationTracker?.openAppSettings();
  }

  /// Applies a device position fix.
  void updatePosition(NavigationPosition position) {
    if (state.isTerminal || state.session == null) return;
    _lastPosition = position;

    var status = state.status;
    if (status == ActiveTripStatus.navigationInitial ||
        status == ActiveTripStatus.navigationAcquiringPosition ||
        status == ActiveTripStatus.navigationPositionUnavailable) {
      status = ActiveTripStatus.navigationActive;
    }
    _emit(
      _withProgress(
        state.copyWith(
          status: status,
          currentLatitude: position.coordinate.latitude,
          currentLongitude: position.coordinate.longitude,
        ),
        position,
      ),
    );

    _detectArrival(position.coordinate, position.accuracyMeters);
    _maybeRequestRoute();
  }

  ActiveTripState _withProgress(
    ActiveTripState next,
    NavigationPosition position,
  ) {
    final target = next.targetItem;
    if (target == null) {
      _offRouteFixes = 0;
      return next.copyWith(
        clearDistance: true,
        clearRemainingDuration: true,
        clearManeuver: true,
        status: next.status == ActiveTripStatus.navigationOffRouteDeviation
            ? ActiveTripStatus.navigationActive
            : null,
      );
    }

    final tracker = _routeTargetItemId == target.itemId ? _routeTracker : null;
    if (tracker == null) {
      _offRouteFixes = 0;
      return next.copyWith(
        status: next.status == ActiveTripStatus.navigationOffRouteDeviation
            ? ActiveTripStatus.navigationActive
            : null,
        distanceToTargetMeters: distanceMeters(
          position.coordinate,
          _coordinateOf(target),
        ),
        clearRemainingDuration: true,
        clearManeuver: true,
      );
    }

    final progress = tracker.progress(position.coordinate);
    final threshold =
        offRouteThresholdMeters +
        math.min(position.accuracyMeters ?? 0, maxAccuracyAllowanceMeters);
    _offRouteFixes = progress.distanceFromRouteMeters > threshold
        ? _offRouteFixes + 1
        : 0;
    final isOffRoute = _offRouteFixes >= offRouteConsecutiveFixes;
    if (isOffRoute &&
        next.status != ActiveTripStatus.navigationOffRouteDeviation) {
      unawaited(_reportDeviation(target.itemId));
    }
    final step = progress.nextStep;

    return next.copyWith(
      status: isOffRoute
          ? ActiveTripStatus.navigationOffRouteDeviation
          : (next.status == ActiveTripStatus.navigationOffRouteDeviation
                ? ActiveTripStatus.navigationActive
                : null),
      distanceToTargetMeters: progress.remainingDistanceMeters,
      remainingDurationSeconds: progress.remainingDurationSeconds,
      currentManeuver: step == null
          ? null
          : ActiveTripManeuver(
              instruction: step.instruction,
              distanceMeters: progress.distanceToNextStepMeters.round(),
              direction: step.direction,
            ),
      clearManeuver: step == null,
    );
  }

  // ───────────────────────────── Guidance ───────────────────────────── //

  void _maybeRequestRoute() {
    final directions = _directionsRepository;
    final target = state.targetItem;
    final position = _lastPosition;
    if (directions == null ||
        !directions.isAvailable ||
        target == null ||
        position == null ||
        _isRouteLoading ||
        state.isTerminal) {
      return;
    }

    final needsRoute =
        _routeTargetItemId != target.itemId ||
        state.status == ActiveTripStatus.navigationOffRouteDeviation;
    if (!needsRoute) return;
    final lastRequest = _lastRouteRequestAt;
    // The cooldown applies per target whether or not the last request
    // succeeded, so an offline device or an unroutable stop cannot cause a
    // request on every GPS fix.
    if (lastRequest != null &&
        _lastRouteRequestTargetId == target.itemId &&
        _clock().difference(lastRequest) < routeRequestCooldown) {
      return;
    }
    unawaited(_fetchRoute(directions, position.coordinate, target));
  }

  Future<void> _fetchRoute(
    RouteDirectionsRepository directions,
    NavigationCoordinate origin,
    NavigationSessionItem target,
  ) async {
    _isRouteLoading = true;
    _lastRouteRequestAt = _clock();
    _lastRouteRequestTargetId = target.itemId;
    try {
      final route = await directions.getRoute(
        origin: origin,
        destination: _coordinateOf(target),
        // Each leg may use its own mode; older sessions only carry the
        // trip-wide one.
        transportMode:
            target.transportModeFromPrevious ?? state.session?.transportMode,
      );
      if (isClosed || state.targetItemId != target.itemId) return;
      _routeTracker = RouteProgressTracker(route);
      _routeTargetItemId = target.itemId;
      _offRouteFixes = 0;
      var next = state.copyWith(
        route: route,
        status: state.status == ActiveTripStatus.navigationOffRouteDeviation
            ? ActiveTripStatus.navigationActive
            : null,
      );
      final position = _lastPosition;
      if (position != null) next = _withProgress(next, position);
      _emit(next);
    } on Failure {
      // Guidance is best effort: keep straight-line distance and retry after
      // the cooldown.
    } finally {
      _isRouteLoading = false;
    }
  }

  /// Chooses which stop to head to. Any Pending or Skipped stop is allowed.
  /// While exploring, the Traveler first departs from the current stop.
  Future<void> selectTarget(int itemId) async {
    final item = state.session?.itemById(itemId);
    if (item == null || !item.isReachable || state.isTerminal) return;
    if (state.isExploring) {
      await depart(targetItemId: itemId);
      return;
    }
    _setTarget(itemId);
  }

  void _setTarget(int? itemId) {
    if (state.targetItemId == itemId) return;
    _routeTracker = null;
    _routeTargetItemId = null;
    _lastRouteRequestAt = null;
    _lastRouteRequestTargetId = null;
    _offRouteFixes = 0;
    var next = state.copyWith(
      targetItemId: itemId,
      clearTarget: itemId == null,
      clearRoute: true,
      clearManeuver: true,
      clearDistance: true,
      clearRemainingDuration: true,
    );
    final position = _lastPosition;
    if (position != null) next = _withProgress(next, position);
    _emit(next);
    _maybeRequestRoute();
  }

  // ───────────────────────────── Arrival ────────────────────────────── //

  void _detectArrival(NavigationCoordinate coordinate, double? accuracy) {
    final session = state.session;
    final position = NavigationPosition(
      coordinate: coordinate,
      timestamp: _clock(),
      accuracyMeters: accuracy,
    );
    // A pending question about a stop the Traveler has since walked away from
    // is withdrawn instead of lingering with a stale stop name.
    final promptItemId = state.arrivalPromptItemId;
    final promptItem = promptItemId == null
        ? null
        : session?.itemById(promptItemId);
    if (promptItem != null &&
        !state.isSubmitting &&
        _arrivalDetector.hasLeft(position: position, item: promptItem)) {
      _emit(state.copyWith(clearArrivalPrompt: true));
      return;
    }
    // While exploring, the Traveler is at a stop; nearby stops must not be
    // proposed until they depart (they can still pick a stop manually).
    if (session == null ||
        session.isCompleted ||
        session.isExploring ||
        state.arrivalPromptItemId != null ||
        state.isSubmitting) {
      return;
    }
    // Dwell time keeps counting while another dialog is open, so the question
    // appears as soon as that dialog closes.
    final itemId = _arrivalDetector.update(
      position: position,
      candidates: session.reachableItems,
    );
    if (itemId != null && !_arrivalPromptsPaused) _promptArrival(itemId);
  }

  void _promptArrival(int itemId) {
    _arrivalDetectedAt = _clock();
    _emit(state.copyWith(arrivalPromptItemId: itemId));
  }

  /// The Traveler confirmed the detected arrival.
  Future<void> confirmArrival() async {
    final itemId = state.arrivalPromptItemId;
    if (itemId == null) return;
    final occurredAt = _arrivalDetectedAt ?? _clock();
    _emit(state.copyWith(clearArrivalPrompt: true));
    await reachItem(itemId, occurredAt: occurredAt);
  }

  /// Holds arrival questions while another dialog is on screen.
  void pauseArrivalPrompts() => _arrivalPromptsPaused = true;

  void resumeArrivalPrompts() => _arrivalPromptsPaused = false;

  /// Sends the last failed progress action again (SnackBar "Retry").
  Future<void> retryLastAction() async {
    final action = _retryAction;
    _retryAction = null;
    if (action != null) await action();
  }

  /// The Traveler answered "Not yet": stop proposing this stop until they
  /// leave its area.
  void dismissArrivalPrompt() {
    final itemId = state.arrivalPromptItemId;
    if (itemId == null) return;
    _arrivalDetector.suppress(itemId);
    _emit(state.copyWith(clearArrivalPrompt: true));
  }

  // ─────────────────────────── Progress actions ──────────────────────── //

  Future<void> reachItem(int itemId, {DateTime? occurredAt}) async {
    final item = state.session?.itemById(itemId);
    if (item == null) return;
    final time = occurredAt ?? _clock();
    await _mutate(
      (sessionId) => _sessionRepository.reachItem(
        sessionId: sessionId,
        itemId: itemId,
        occurredAt: time,
      ),
      successMessage: 'Arrived at ${item.poiName}.',
      retry: () => reachItem(itemId, occurredAt: time),
    );
  }

  Future<void> skipItem(int itemId) async {
    final item = state.session?.itemById(itemId);
    if (item == null) return;
    final time = _clock();
    await _mutate(
      (sessionId) => _sessionRepository.skipItem(
        sessionId: sessionId,
        itemId: itemId,
        occurredAt: time,
      ),
      successMessage: 'Skipped ${item.poiName}.',
      retry: () => skipItem(itemId),
      // Skipping the stop the Traveler was heading to moves on to the next one.
      keepCurrentTarget: itemId != state.targetItemId,
    );
  }

  /// Leaves the current stop and heads to [targetItemId] or the suggested
  /// next stop.
  Future<void> depart({int? targetItemId}) async {
    final time = _clock();
    await _mutate(
      (sessionId) =>
          _sessionRepository.depart(sessionId: sessionId, occurredAt: time),
      preferredTargetId: targetItemId,
      retry: () => depart(targetItemId: targetItemId),
    );
  }

  Future<void> finish() async {
    await _mutate(_sessionRepository.complete, retry: finish);
  }

  Future<void> _mutate(
    Future<NavigationSession> Function(int sessionId) action, {
    String? successMessage,
    int? preferredTargetId,
    bool keepCurrentTarget = true,
    Future<void> Function()? retry,
  }) async {
    final session = state.session;
    if (session == null || session.isCompleted || state.isSubmitting) return;
    if (!state.isOnline) {
      _retryAction = retry;
      _emit(
        state.copyWith(
          feedback: _feedback(
            offlineMessage,
            isError: true,
            canRetry: retry != null,
          ),
        ),
      );
      return;
    }
    _retryAction = null;
    _emit(state.copyWith(isSubmitting: true));
    try {
      final updated = await action(session.sessionId);
      _applySession(
        updated,
        feedback: successMessage,
        preferredTargetId:
            preferredTargetId ??
            (keepCurrentTarget ? state.targetItemId : null),
      );
    } on NavigationFailure catch (failure) {
      final refreshed =
          failure.reason == NavigationFailureReason.sessionCompleted ||
              failure.reason == NavigationFailureReason.itemAlreadyReached
          ? await _tryRefresh(session.sessionId)
          : null;
      if (refreshed != null) {
        _applySession(
          refreshed,
          feedback: failure.message,
          isError: true,
          preferredTargetId: state.targetItemId,
        );
      } else {
        _emit(
          state.copyWith(
            isSubmitting: false,
            feedback: _feedback(failure.message, isError: true),
          ),
        );
      }
    } on Failure catch (failure) {
      // Transport failures (timeout, no connection) are worth retrying;
      // business rejections are not.
      _retryAction = retry;
      _emit(
        state.copyWith(
          isSubmitting: false,
          feedback: _feedback(
            failure.message,
            isError: true,
            canRetry: retry != null,
          ),
        ),
      );
    }
  }

  Future<NavigationSession?> _tryRefresh(int sessionId) async {
    try {
      return await _sessionRepository.getById(sessionId);
    } on Failure {
      return null;
    }
  }

  void _applySession(
    NavigationSession session, {
    String? feedback,
    bool isError = false,
    int? preferredTargetId,
  }) {
    if (isClosed) return;
    final completed = session.isCompleted;
    // A new leg starts after departing: dwell time is counted afresh.
    if (state.isExploring && !session.isExploring) _arrivalDetector.reset();
    final targetId = completed || session.isExploring
        ? null
        : _chooseTarget(session, preferredTargetId);

    _emit(
      state.copyWith(
        session: session,
        itineraryVersion: session.itineraryVersion,
        isSubmitting: false,
        clearArrivalPrompt:
            completed ||
            (state.arrivalPromptItemId != null &&
                !(session.itemById(state.arrivalPromptItemId)?.isReachable ??
                    false)),
        status: completed ? ActiveTripStatus.navigationTripCompleted : null,
        isRerouteSheetVisible: completed ? false : null,
        feedback: feedback == null
            ? null
            : _feedback(feedback, isError: isError),
      ),
    );
    if (completed) {
      unawaited(_stopTracking(invalidate: true));
      _routeTracker = null;
      _routeTargetItemId = null;
      _emit(
        state.copyWith(
          clearTarget: true,
          clearRoute: true,
          clearManeuver: true,
          clearDistance: true,
          clearRemainingDuration: true,
        ),
      );
      return;
    }
    _setTarget(targetId);
  }

  /// Keeps the current target while it is still reachable; otherwise uses the
  /// Backend suggestion. Skipped stops are targeted only when the Traveler
  /// explicitly chooses them.
  static int? _chooseTarget(NavigationSession session, int? preferredId) {
    final preferred = session.itemById(preferredId);
    if (preferred != null && preferred.isReachable) return preferred.itemId;
    return session.nextItemId;
  }

  static NavigationCoordinate _coordinateOf(NavigationSessionItem item) =>
      NavigationCoordinate(latitude: item.latitude, longitude: item.longitude);

  ActiveTripFeedback _feedback(
    String message, {
    bool isError = false,
    bool canRetry = false,
  }) => ActiveTripFeedback(
    id: ++_feedbackId,
    message: message,
    isError: isError,
    canRetry: canRetry,
  );

  void _emit(ActiveTripState next) {
    if (!isClosed) emit(next);
  }

  @override
  Future<void> close() async {
    await _connectivitySubscription?.cancel();
    await _pushHintSubscription?.cancel();
    await _stopTracking(invalidate: true);
    return super.close();
  }

  /// Keeps the Online/Offline badge in step with the device connection.
  void _watchConnectivity() {
    final networkInfo = _networkInfo;
    if (networkInfo == null || _connectivitySubscription != null) return;
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (state.isOnline != isOnline) _emit(state.copyWith(isOnline: isOnline));
      if (isOnline && state.session != null && !state.isDemoMode) {
        unawaited(refreshAlerts());
      }
    }, onError: (Object _) {});
    unawaited(
      networkInfo.isConnected
          .then((isOnline) {
            if (!isClosed && state.isOnline != isOnline) {
              _emit(state.copyWith(isOnline: isOnline));
            }
          })
          .catchError((Object _) {}),
    );
  }

  // ─────────────────────────── UC-14 alerts ─────────────────────────── //

  Future<void> refreshAlerts() async {
    final repository = _alertRepository;
    final sessionId = state.session?.sessionId;
    if (repository == null || sessionId == null || state.isTerminal) return;
    final generation = ++_alertRefreshGeneration;
    _emit(
      state.copyWith(
        alertRefreshStatus: AlertRefreshStatus.loading,
        clearAlertRefreshError: true,
      ),
    );
    List<TripAlert>? loadedAlerts;
    List<WeatherAdvisory>? loadedAdvisories;
    var alertFailed = false;
    var advisoryFailed = false;
    await Future.wait<void>([
      () async {
        try {
          loadedAlerts = await repository.listAlerts(sessionId);
        } on Failure {
          alertFailed = true;
          // Preserve the last server-backed alert list.
        }
      }(),
      () async {
        try {
          loadedAdvisories = await repository.listWeatherAdvisories(sessionId);
        } on Failure {
          advisoryFailed = true;
          // Preserve the current advisory independently from alert history.
        }
      }(),
    ]);
    if (isClosed || generation != _alertRefreshGeneration) return;
    if (loadedAlerts == null && loadedAdvisories == null) {
      _emit(
        state.copyWith(
          alertRefreshStatus: AlertRefreshStatus.failure,
          alertRefreshError: 'Could not refresh alerts. Try again.',
        ),
      );
      return;
    }

    final alerts = (loadedAlerts ?? state.alerts).toList()
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
    final previousById = {for (final alert in state.alerts) alert.id: alert};
    final merged = alerts
        .map((alert) {
          final previous = previousById[alert.id];
          return alert.copyWith(
            isRead: alert.isRead || (previous?.isRead ?? false),
            isDismissedFromBanner:
                alert.isDismissedFromBanner ||
                (previous?.isDismissedFromBanner ?? false),
          );
        })
        .toList(growable: false);
    final banner = merged.cast<TripAlert?>().firstWhere(
      (alert) =>
          alert != null &&
          !alert.isRead &&
          !alert.isResolved &&
          !alert.isDismissedFromBanner,
      orElse: () => null,
    );
    final persistedRainItemIds = merged
        .where(
          (alert) =>
              alert.messageCode == 'trip_alert.weather_advisory' &&
              !alert.isResolved &&
              alert.affectedItemId != null,
        )
        .map((alert) => alert.affectedItemId)
        .toSet();
    final advisory = loadedAdvisories == null
        ? state.activeWeatherAdvisory
        : loadedAdvisories!.cast<WeatherAdvisory?>().firstWhere(
            (item) =>
                item != null &&
                !persistedRainItemIds.contains(item.itemId) &&
                !_weatherAdvisoryStore.isDismissed(item.advisoryKey),
            orElse: () => null,
          );
    _emit(
      state.copyWith(
        alerts: merged,
        activeBannerAlert: banner,
        clearBannerAlert: banner == null,
        activeWeatherAdvisory: advisory,
        clearWeatherAdvisory:
            advisory == null || persistedRainItemIds.contains(advisory.itemId),
        alertRefreshStatus: alertFailed || advisoryFailed
            ? AlertRefreshStatus.failure
            : AlertRefreshStatus.success,
        alertRefreshError: alertFailed || advisoryFailed
            ? 'Some alerts could not be refreshed.'
            : null,
        clearAlertRefreshError: !alertFailed && !advisoryFailed,
      ),
    );
  }

  Future<void> acknowledgeAlert(TripAlert alert) async {
    final repository = _alertRepository;
    final sessionId = state.session?.sessionId;
    final incidentId = int.tryParse(alert.id);
    if (repository == null || sessionId == null || incidentId == null) return;
    try {
      await repository.acknowledgeAlert(
        sessionId: sessionId,
        incidentId: incidentId,
      );
      final updated = state.alerts
          .map(
            (item) => item.id == alert.id ? item.copyWith(isRead: true) : item,
          )
          .toList(growable: false);
      _emit(
        state.copyWith(
          alerts: updated,
          clearBannerAlert: state.activeBannerAlert?.id == alert.id,
        ),
      );
    } on Failure catch (failure) {
      _emit(
        state.copyWith(feedback: _feedback(failure.message, isError: true)),
      );
    }
  }

  void dismissWeatherAdvisory() {
    final advisory = state.activeWeatherAdvisory;
    if (advisory == null) return;
    _weatherAdvisoryStore.dismiss(advisory.advisoryKey);
    _emit(state.copyWith(clearWeatherAdvisory: true));
  }

  Future<void> _reportDeviation(int targetItemId) async {
    final repository = _alertRepository;
    final sessionId = state.session?.sessionId;
    if (repository == null || sessionId == null) return;
    final eventId = const Uuid().v4();
    final observedAtUtc = _clock().toUtc();
    var transportAttempts = 0;
    try {
      late TripAlert alert;
      while (true) {
        try {
          alert = await repository.reportDeviation(
            sessionId: sessionId,
            eventId: eventId,
            observedAtUtc: observedAtUtc,
            targetItemId: targetItemId,
          );
          break;
        } on NetworkFailure {
          if (++transportAttempts >= 2) rethrow;
        }
      }
      if (!state.alerts.any((item) => item.id == alert.id)) addAlert(alert);
    } on RateLimitFailure {
      // Backend cooldown is authoritative. Do not retry this transition.
    } on Failure {
      // A future on-route -> off-route transition creates a fresh event.
    }
  }

  /// Dismisses banner alert. The alert REMAINS in alerts history.
  void dismissBannerAlert(String alertId) {
    final updatedAlerts = state.alerts.map((a) {
      if (a.id == alertId) {
        return a.copyWith(isDismissedFromBanner: true);
      }
      return a;
    }).toList();

    emit(state.copyWith(alerts: updatedAlerts, clearBannerAlert: true));
  }

  /// Adds an alert to the active feed and surfaces it in the banner if appropriate.
  void addAlert(TripAlert alert) {
    if (state.isTerminal) return;
    final updatedAlerts = [alert, ...state.alerts];
    emit(state.copyWith(alerts: updatedAlerts, activeBannerAlert: alert));
  }

  // ─────────────────── UC-15 re-routing (demo backed) ─────────────────── //

  /// Opens reroute proposal sheet for user review.
  /// A proposal may be reviewed/actioned only when its status is pending.
  /// If proposal is null:
  /// - In production mode: does not invent or reopen non-pending proposals.
  /// - In demo mode: generates a sample demo proposal if none is active.
  void openRerouteProposal([RerouteProposal? proposal]) {
    if (state.isTerminal) return;
    final target = proposal ?? state.activeRerouteProposal;
    if (target == null) {
      if (!state.isDemoMode) return;
      final demoProposal = ActiveTripDemoFixtures.createSampleRerouteProposal();
      emit(
        state.copyWith(
          activeRerouteProposal: demoProposal,
          isRerouteSheetVisible: true,
        ),
      );
      return;
    }

    // Terminal proposals (accepted, declined, expired) cannot be reopened
    if (target.status != RerouteStatus.pending) return;

    emit(
      state.copyWith(
        activeRerouteProposal: target,
        isRerouteSheetVisible: true,
      ),
    );
  }

  /// Closes proposal sheet without decision.
  void closeRerouteProposalSheet() {
    if (!state.isRerouteSheetVisible) return;
    emit(state.copyWith(isRerouteSheetVisible: false));
  }

  /// UC-15 Traveler accepts the reroute proposal.
  /// Explicit consent creates a new itinerary version (V+1).
  /// Requires activeRerouteProposal != null and status == pending.
  void acceptRerouteProposal() {
    if (state.isTerminal) return;
    final proposal = state.activeRerouteProposal;
    if (proposal == null || proposal.status != RerouteStatus.pending) return;

    final acceptedProposal = proposal.copyWith(status: RerouteStatus.accepted);
    final nextVersion = state.itineraryVersion + 1;

    // In demo preview, simulate applying shelter stop
    var session = state.session;
    if (state.isDemoMode && session != null && session.items.length >= 4) {
      final items = List<NavigationSessionItem>.from(session.items);
      items[3] = items[3].copyWith(poiName: 'Helio Center [Indoor Shelter]');
      session = session.copyWith(items: items);
    }

    emit(
      state.copyWith(
        itineraryVersion: nextVersion,
        session: session,
        activeRerouteProposal: acceptedProposal,
        isRerouteSheetVisible: false,
        status: ActiveTripStatus.navigationActive,
        statusMessage:
            'Itinerary updated to v$nextVersion with weather-safe route.',
      ),
    );
  }

  /// UC-15 Traveler declines the reroute proposal.
  /// Current route and version remain active.
  /// Requires activeRerouteProposal != null and status == pending.
  void declineRerouteProposal() {
    if (state.isTerminal) return;
    final proposal = state.activeRerouteProposal;
    if (proposal == null || proposal.status != RerouteStatus.pending) return;

    final declinedProposal = proposal.copyWith(status: RerouteStatus.declined);
    emit(
      state.copyWith(
        activeRerouteProposal: declinedProposal,
        isRerouteSheetVisible: false,
        status: ActiveTripStatus.navigationActive,
        statusMessage: 'Reroute declined. Continuing on current itinerary.',
      ),
    );
  }

  /// Proposal expires. Current route remains active.
  /// Requires activeRerouteProposal != null and status == pending.
  void expireRerouteProposal() {
    if (state.isTerminal) return;
    final proposal = state.activeRerouteProposal;
    if (proposal == null || proposal.status != RerouteStatus.pending) return;

    final expiredProposal = proposal.copyWith(status: RerouteStatus.expired);
    emit(
      state.copyWith(
        activeRerouteProposal: expiredProposal,
        isRerouteSheetVisible: false,
        status: ActiveTripStatus.navigationActive,
        statusMessage: 'Suggestion expired. Current plan remains in force.',
      ),
    );
  }

  // =========================================================================
  // DEMO_ONLY SIMULATION CONTROLS
  // Clearly isolated from production actions for visual review & testing
  // =========================================================================

  /// DEMO_ONLY: Simulates GPS arrival detection at the current target, which
  /// raises the same confirmation prompt as a real detection.
  void demoSimulateArrivalAtNextStop() {
    if (!state.isDemoMode || state.isTerminal) return;
    final itemId =
        state.targetItemId ??
        (state.session?.reachableItems.firstOrNull?.itemId);
    if (itemId == null || state.arrivalPromptItemId != null) return;
    _promptArrival(itemId);
  }

  /// DEMO_ONLY: Injects a severe weather disruption with reroute proposal.
  void demoSimulateWeatherDisruption() {
    if (!state.isDemoMode || state.isTerminal) return;
    final alert = TripAlert(
      id: 'demo-weather-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Severe weather warning',
      description:
          'Heavy rainfall (45 mm/h) detected along upcoming route segment.',
      severity: AlertSeverity.critical,
      type: TripAlertType.weather,
      affectedStopName: state.targetItem?.poiName ?? 'Next stop',
      timestamp: DateTime.now(),
      rerouteProposalAvailable: true,
    );
    final proposal = ActiveTripDemoFixtures.createSampleRerouteProposal();

    emit(
      state.copyWith(
        alerts: [alert, ...state.alerts],
        activeBannerAlert: alert,
        activeRerouteProposal: proposal,
        status: ActiveTripStatus.navigationActive,
      ),
    );
  }

  /// DEMO_ONLY: Injects route deviation event (>500m).
  void demoSimulateRouteDeviation() {
    if (!state.isDemoMode || state.isTerminal) return;
    final alert = TripAlert(
      id: 'demo-deviation-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Off-route deviation detected',
      description: 'You have deviated from planned route by >500m.',
      severity: AlertSeverity.critical,
      type: TripAlertType.deviation,
      affectedStopName: 'Off-route segment',
      timestamp: DateTime.now(),
      rerouteProposalAvailable: true,
    );
    emit(
      state.copyWith(
        status: ActiveTripStatus.navigationOffRouteDeviation,
        alerts: [alert, ...state.alerts],
        activeBannerAlert: alert,
        activeRerouteProposal:
            ActiveTripDemoFixtures.createSampleRerouteProposal(),
      ),
    );
  }

  /// DEMO_ONLY: Toggles GPS acquiring state.
  void demoSimulateGpsAcquiring() {
    if (!state.isDemoMode || state.isTerminal) return;
    emit(state.copyWith(status: ActiveTripStatus.navigationAcquiringPosition));
  }

  /// DEMO_ONLY: Simulates GPS unavailable state.
  void demoSimulateGpsLost() {
    if (!state.isDemoMode || state.isTerminal) return;
    emit(
      state.copyWith(status: ActiveTripStatus.navigationPositionUnavailable),
    );
  }

  /// DEMO_ONLY: Simulates permission denied state.
  void demoSimulatePermissionDenied() {
    if (!state.isDemoMode || state.isTerminal) return;
    emit(state.copyWith(status: ActiveTripStatus.navigationPermissionDenied));
  }
}
