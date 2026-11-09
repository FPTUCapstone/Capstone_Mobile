import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';

enum EmergencyEvidenceStatus { idle, submitting, saved, withdrawn, failure }

final class EmergencyEvidenceState extends Equatable {
  const EmergencyEvidenceState({
    this.status = EmergencyEvidenceStatus.idle,
    this.current,
    this.failure,
  });

  final EmergencyEvidenceStatus status;

  /// What the Backend holds; an edit starts from this and saves against it.
  final EmergencyEvidenceSnapshot? current;
  final Failure? failure;

  @override
  List<Object?> get props => [status, current, failure];
}

/// Reads, updates or withdraws the evidence of a committed emergency operation.
final class EmergencyEvidenceCubit extends Cubit<EmergencyEvidenceState> {
  EmergencyEvidenceCubit({
    required int tourId,
    required int scheduleId,
    required SaveEmergencyEvidenceUseCase save,
    required WithdrawEmergencyEvidenceUseCase withdraw,
    required GetEmergencyEvidenceUseCase read,
    required NetworkInfo networkInfo,
  }) : _tourId = tourId,
       _scheduleId = scheduleId,
       _save = save,
       _withdraw = withdraw,
       _read = read,
       _networkInfo = networkInfo,
       super(const EmergencyEvidenceState());

  final int _tourId;
  final int _scheduleId;
  final SaveEmergencyEvidenceUseCase _save;
  final WithdrawEmergencyEvidenceUseCase _withdraw;
  final GetEmergencyEvidenceUseCase _read;
  final NetworkInfo _networkInfo;

  Future<void> load() async {
    try {
      final current = await _read(tourId: _tourId, scheduleId: _scheduleId);
      if (!isClosed) {
        emit(
          EmergencyEvidenceState(
            status: state.status,
            current: current,
            failure: state.failure,
          ),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          EmergencyEvidenceState(
            status: EmergencyEvidenceStatus.failure,
            current: state.current,
            failure: failure,
          ),
        );
      }
    }
  }

  Future<void> saveEvidence(EmergencyEvidence evidence) => _run(
    EmergencyEvidenceStatus.saved,
    () => _save(
      tourId: _tourId,
      scheduleId: _scheduleId,
      evidence: evidence,
      expectedVersion: state.current?.version,
    ),
  );

  Future<void> withdrawEvidence() => _run(
    EmergencyEvidenceStatus.withdrawn,
    () => _withdraw(
      tourId: _tourId,
      scheduleId: _scheduleId,
      expectedVersion: state.current?.version,
    ),
  );

  Future<void> _run(
    EmergencyEvidenceStatus done,
    Future<void> Function() action,
  ) async {
    // Without the current evidence an edit could silently erase saved values.
    if (state.status == EmergencyEvidenceStatus.submitting ||
        state.current == null) {
      return;
    }
    emit(
      EmergencyEvidenceState(
        status: EmergencyEvidenceStatus.submitting,
        current: state.current,
      ),
    );
    if (!await _networkInfo.isConnected) {
      _fail(const NetworkFailure());
      return;
    }
    try {
      await action();
      if (isClosed) return;
      emit(EmergencyEvidenceState(status: done, current: state.current));
      await load();
    } on EmergencyTourFailure catch (failure) {
      // The evidence moved on: show what the Backend holds now.
      _fail(failure);
      await load();
    } on Failure catch (failure) {
      _fail(failure);
    }
  }

  void _fail(Failure failure) {
    if (isClosed) return;
    emit(
      EmergencyEvidenceState(
        status: EmergencyEvidenceStatus.failure,
        current: state.current,
        failure: failure,
      ),
    );
  }
}
