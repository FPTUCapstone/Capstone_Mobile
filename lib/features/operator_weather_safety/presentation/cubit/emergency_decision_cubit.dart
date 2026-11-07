import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_state.dart';
import 'package:uuid/uuid.dart';

/// Drives one manual Cancel Before Departure or Emergency Stop decision. Every
/// step re-reads the Backend impact and fails closed; nothing is ever queued or
/// retried without the Operator asking for it.
final class EmergencyDecisionCubit extends Cubit<EmergencyDecisionState> {
  EmergencyDecisionCubit({
    required int tourId,
    required int scheduleId,
    required GetEmergencyImpactUseCase getImpact,
    required CancelBeforeDepartureUseCase cancelBeforeDeparture,
    required EmergencyStopTourUseCase emergencyStop,
    required NetworkInfo networkInfo,
    String Function()? newIdempotencyKey,
  }) : _tourId = tourId,
       _scheduleId = scheduleId,
       _getImpact = getImpact,
       _cancelBeforeDeparture = cancelBeforeDeparture,
       _emergencyStop = emergencyStop,
       _networkInfo = networkInfo,
       _newKey = newIdempotencyKey ?? const Uuid().v4,
       super(const EmergencyDecisionState()) {
    _connectivity = _networkInfo.onConnectivityChanged.listen((connected) {
      if (!connected && state.stage == EmergencyDecisionStage.ready) {
        _emitBlocked(EmergencyBlockReason.offline);
      } else if (connected &&
          state.blockReason == EmergencyBlockReason.offline) {
        unawaited(load());
      }
    });
  }

  final int _tourId;
  final int _scheduleId;
  final GetEmergencyImpactUseCase _getImpact;
  final CancelBeforeDepartureUseCase _cancelBeforeDeparture;
  final EmergencyStopTourUseCase _emergencyStop;
  final NetworkInfo _networkInfo;
  final String Function() _newKey;
  late final StreamSubscription<bool> _connectivity;

  /// The last submitted payload and its key: an identical payload is the same
  /// intent and keeps the key, anything else is a new intent.
  EmergencyDecision? _intentDecision;
  String? _intentKey;

  Future<void> load() async {
    final impact = await _freshImpact();
    if (impact != null && !isClosed) _emitReady(impact);
  }

  /// Re-reads the impact after the app returns, leaving any confirmation, submit
  /// or final state alone. A change is flagged for the Operator to review.
  Future<void> refreshOnResume() async {
    final stage = state.stage;
    if (stage != EmergencyDecisionStage.ready &&
        state.blockReason != EmergencyBlockReason.offline &&
        state.blockReason != EmergencyBlockReason.unavailable) {
      return;
    }
    final reviewed = state.impact;
    final impact = await _freshImpact();
    if (impact == null || isClosed || state.stage != stage) return;
    _emitReady(
      impact,
      impactChanged: reviewed != null && _differs(impact, reviewed),
    );
  }

  /// The version does not cover the action, which changes when the start time
  /// passes, so both must match for a review to still be valid.
  static bool _differs(EmergencyImpact impact, EmergencyImpact reviewed) =>
      impact.impactVersion != reviewed.impactVersion ||
      impact.action != reviewed.action;

  /// Re-reads the impact; a change refuses the confirmation and asks the
  /// Operator to review it. [draft]'s version is replaced by the checked one.
  Future<void> prepareConfirmation(EmergencyDecision draft) async {
    if (state.stage != EmergencyDecisionStage.ready) return;
    final reviewed = state.impact;
    emit(
      EmergencyDecisionState(
        stage: EmergencyDecisionStage.checkingImpact,
        impact: reviewed,
      ),
    );
    final impact = await _freshImpact();
    if (impact == null || isClosed) return;
    if (reviewed == null || _differs(impact, reviewed)) {
      _emitReady(impact, impactChanged: true);
      return;
    }
    emit(
      EmergencyDecisionState(
        stage: EmergencyDecisionStage.awaitingConfirmation,
        impact: impact,
        pendingDecision: draft.withImpactVersion(impact.impactVersion),
      ),
    );
  }

  void dismissConfirmation() {
    if (state.stage != EmergencyDecisionStage.awaitingConfirmation) return;
    emit(
      EmergencyDecisionState(
        stage: EmergencyDecisionStage.ready,
        impact: state.impact,
      ),
    );
  }

  /// Submits the confirmed decision after one last impact check.
  Future<void> confirm({String? currentPassword}) async {
    final decision = state.pendingDecision;
    if (state.stage != EmergencyDecisionStage.awaitingConfirmation ||
        decision == null) {
      return;
    }
    if (_missesPassword(decision, currentPassword)) {
      emit(
        EmergencyDecisionState(
          stage: EmergencyDecisionStage.ready,
          impact: state.impact,
          failure: const ValidationFailure('Vui lòng nhập mật khẩu hiện tại.'),
        ),
      );
      return;
    }
    final confirmed = state.impact;
    emit(
      EmergencyDecisionState(
        stage: EmergencyDecisionStage.submitting,
        impact: confirmed,
        pendingDecision: decision,
      ),
    );
    final impact = await _freshImpact();
    if (impact == null || isClosed) return;
    if (confirmed == null || _differs(impact, confirmed)) {
      _emitReady(impact, impactChanged: true);
      return;
    }
    await _submit(decision, currentPassword);
  }

  /// Replays the frozen request of an ambiguous submit under the same key. The
  /// impact is not re-read: if the first attempt committed, that read would be
  /// rejected, while this replay returns the original result.
  Future<void> retry({String? currentPassword}) async {
    final decision = state.pendingDecision;
    if (state.stage != EmergencyDecisionStage.ambiguous || decision == null) {
      return;
    }
    if (_missesPassword(decision, currentPassword)) {
      emit(
        EmergencyDecisionState(
          stage: EmergencyDecisionStage.ambiguous,
          impact: state.impact,
          pendingDecision: decision,
          failure: const ValidationFailure('Vui lòng nhập mật khẩu hiện tại.'),
        ),
      );
      return;
    }
    if (!await _networkInfo.isConnected) {
      if (isClosed) return;
      emit(
        EmergencyDecisionState(
          stage: EmergencyDecisionStage.ambiguous,
          impact: state.impact,
          pendingDecision: decision,
          failure: const NetworkFailure(),
        ),
      );
      return;
    }
    if (isClosed) return;
    emit(
      EmergencyDecisionState(
        stage: EmergencyDecisionStage.submitting,
        impact: state.impact,
        pendingDecision: decision,
      ),
    );
    await _submit(decision, currentPassword);
  }

  bool _missesPassword(EmergencyDecision decision, String? password) =>
      decision is EmergencyStopDecision &&
      (password == null || password.isEmpty);

  Future<void> _submit(EmergencyDecision decision, String? password) async {
    if (decision != _intentDecision) {
      _intentDecision = decision;
      _intentKey = _newKey();
    }
    final key = _intentKey!;
    try {
      final result = await switch (decision) {
        final CancelBeforeDepartureDecision cancel => _cancelBeforeDeparture(
          cancel,
          idempotencyKey: key,
        ),
        final EmergencyStopDecision stop => _emergencyStop(
          stop,
          currentPassword: password!,
          idempotencyKey: key,
        ),
      };
      if (isClosed) return;
      emit(
        EmergencyDecisionState(
          stage: EmergencyDecisionStage.succeeded,
          impact: state.impact,
          result: result,
        ),
      );
    } on Failure catch (failure) {
      if (!isClosed) await _onSubmitFailure(failure, decision);
    }
  }

  Future<void> _onSubmitFailure(
    Failure failure,
    EmergencyDecision decision,
  ) async {
    switch (failure) {
      case NotFoundFailure():
        emit(
          const EmergencyDecisionState(stage: EmergencyDecisionStage.notFound),
        );
      case PermissionFailure():
        _emitBlocked(EmergencyBlockReason.forbidden);
      case ValidationFailure() || AuthenticationFailure() || ConflictFailure():
      case ConstraintFailure() || RateLimitFailure():
        _emitFormFailure(failure);
      case EmergencyTourFailure(reason: final reason):
        switch (reason) {
          case EmergencyTourFailureReason.wrongPassword:
            _emitFormFailure(failure);
          case EmergencyTourFailureReason.terminal:
            _emitBlocked(EmergencyBlockReason.terminal);
          case EmergencyTourFailureReason.completed:
            _emitBlocked(EmergencyBlockReason.completed);
          case EmergencyTourFailureReason.unverifiedSessions:
            _emitBlocked(EmergencyBlockReason.unverifiedSessions);
          case EmergencyTourFailureReason.idempotencyMismatch:
            _intentDecision = null;
            _intentKey = null;
            await _reloadAfterRejection();
          case EmergencyTourFailureReason.staleImpact:
          case EmergencyTourFailureReason.wrongActionWindow:
            await _reloadAfterRejection();
          case EmergencyTourFailureReason.reviewClosed:
          case EmergencyTourFailureReason.staleEvidence:
            _emitFormFailure(failure);
        }
      // Timeouts, 5xx and unreadable responses: the command may have committed.
      case _:
        emit(
          EmergencyDecisionState(
            stage: EmergencyDecisionStage.ambiguous,
            impact: state.impact,
            pendingDecision: decision,
            failure: failure,
          ),
        );
    }
  }

  Future<void> _reloadAfterRejection() async {
    final impact = await _freshImpact();
    if (impact != null && !isClosed) _emitReady(impact, impactChanged: true);
  }

  void _emitFormFailure(Failure failure) => emit(
    EmergencyDecisionState(
      stage: EmergencyDecisionStage.ready,
      impact: state.impact,
      failure: failure,
    ),
  );

  /// Null means the state already explains why no decision is possible.
  Future<EmergencyImpact?> _freshImpact() async {
    if (!await _networkInfo.isConnected) {
      if (!isClosed) _emitBlocked(EmergencyBlockReason.offline);
      return null;
    }
    try {
      final impact = await _getImpact(tourId: _tourId, scheduleId: _scheduleId);
      if (isClosed) return null;
      if (impact.hasUnverifiedSessions) {
        _emitBlocked(EmergencyBlockReason.unverifiedSessions, impact: impact);
        return null;
      }
      if (impact.action == EmergencyAction.unknown) {
        _emitBlocked(EmergencyBlockReason.unsupportedAction, impact: impact);
        return null;
      }
      return impact;
    } on NotFoundFailure {
      if (!isClosed) {
        emit(
          const EmergencyDecisionState(stage: EmergencyDecisionStage.notFound),
        );
      }
    } on EmergencyTourFailure catch (failure) {
      if (!isClosed) {
        _emitBlocked(switch (failure.reason) {
          EmergencyTourFailureReason.terminal => EmergencyBlockReason.terminal,
          EmergencyTourFailureReason.completed =>
            EmergencyBlockReason.completed,
          EmergencyTourFailureReason.unverifiedSessions =>
            EmergencyBlockReason.unverifiedSessions,
          _ => EmergencyBlockReason.unavailable,
        });
      }
    } on PermissionFailure {
      if (!isClosed) _emitBlocked(EmergencyBlockReason.forbidden);
    } on NetworkFailure {
      if (!isClosed) _emitBlocked(EmergencyBlockReason.offline);
    } on Failure {
      if (!isClosed) _emitBlocked(EmergencyBlockReason.unavailable);
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _connectivity.cancel();
    return super.close();
  }

  void _emitReady(EmergencyImpact impact, {bool impactChanged = false}) => emit(
    EmergencyDecisionState(
      stage: EmergencyDecisionStage.ready,
      impact: impact,
      impactChanged: impactChanged,
    ),
  );

  void _emitBlocked(EmergencyBlockReason reason, {EmergencyImpact? impact}) =>
      emit(
        EmergencyDecisionState(
          stage: EmergencyDecisionStage.blocked,
          blockReason: reason,
          impact: impact,
        ),
      );
}
