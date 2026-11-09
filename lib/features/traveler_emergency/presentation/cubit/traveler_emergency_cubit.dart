import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/usecases/traveler_emergency_use_cases.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_state.dart';

/// The Traveler's view of one committed emergency decision, always read from
/// REST so a denied or missed notification loses nothing.
final class TravelerEmergencyCubit extends Cubit<TravelerEmergencyState> {
  TravelerEmergencyCubit({
    required int bookingId,
    required GetTravelerEmergencyStatusUseCase getStatus,
    required AcknowledgeTravelerEmergencyStatusUseCase acknowledge,
    required NetworkInfo networkInfo,
  }) : _bookingId = bookingId,
       _getStatus = getStatus,
       _acknowledge = acknowledge,
       _networkInfo = networkInfo,
       super(const TravelerEmergencyState()) {
    _connectivity = _networkInfo.onConnectivityChanged.listen((connected) {
      if (connected) unawaited(load());
    });
  }

  final int _bookingId;
  final GetTravelerEmergencyStatusUseCase _getStatus;
  final AcknowledgeTravelerEmergencyStatusUseCase _acknowledge;
  final NetworkInfo _networkInfo;
  late final StreamSubscription<bool> _connectivity;

  /// Bumped by every load and acknowledgement; a slower response that started
  /// earlier must not overwrite newer state.
  int _latest = 0;

  Future<void> load() async {
    final request = ++_latest;
    if (!await _networkInfo.isConnected) {
      if (isClosed) return;
      if (state.emergency != null) {
        _emitStale();
        return;
      }
      emit(
        const TravelerEmergencyState(
          status: TravelerEmergencyLoadStatus.failure,
          failure: NetworkFailure(),
        ),
      );
      return;
    }
    try {
      final emergency = await _getStatus(_bookingId);
      if (isClosed || request != _latest) return;
      emit(
        TravelerEmergencyState(
          status: TravelerEmergencyLoadStatus.ready,
          emergency: emergency,
          actionFailure: state.actionFailure,
          isAcknowledging: state.isAcknowledging,
        ),
      );
    } on NotFoundFailure {
      if (isClosed || request != _latest) return;
      emit(
        const TravelerEmergencyState(
          status: TravelerEmergencyLoadStatus.notFound,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed || request != _latest) return;
      if (state.emergency != null) {
        _emitStale();
        return;
      }
      emit(
        TravelerEmergencyState(
          status: TravelerEmergencyLoadStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  Future<void> acknowledgeNotice() async {
    final current = state.emergency;
    if (current == null || current.isAcknowledged || state.isAcknowledging) {
      return;
    }
    _latest++;
    emit(_ready(isAcknowledging: true));
    if (!await _networkInfo.isConnected) {
      if (!isClosed) emit(_ready(actionFailure: const NetworkFailure()));
      return;
    }
    try {
      final acknowledgedAt = await _acknowledge(_bookingId);
      if (isClosed) return;
      _latest++;
      emit(
        TravelerEmergencyState(
          status: TravelerEmergencyLoadStatus.ready,
          emergency: current.acknowledged(acknowledgedAt),
        ),
      );
    } on NotFoundFailure {
      if (isClosed) return;
      emit(
        const TravelerEmergencyState(
          status: TravelerEmergencyLoadStatus.notFound,
        ),
      );
    } on Failure catch (failure) {
      if (!isClosed) emit(_ready(actionFailure: failure));
    }
  }

  void _emitStale() => emit(
    TravelerEmergencyState(
      status: TravelerEmergencyLoadStatus.ready,
      emergency: state.emergency,
      actionFailure: state.actionFailure,
      isAcknowledging: state.isAcknowledging,
      isStale: true,
    ),
  );

  TravelerEmergencyState _ready({
    bool isAcknowledging = false,
    Failure? actionFailure,
  }) => TravelerEmergencyState(
    status: TravelerEmergencyLoadStatus.ready,
    emergency: state.emergency,
    actionFailure: actionFailure,
    isAcknowledging: isAcknowledging,
  );

  @override
  Future<void> close() async {
    await _connectivity.cancel();
    return super.close();
  }
}
