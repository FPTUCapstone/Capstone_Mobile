import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/usecases/operator_check_in_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_state.dart';

class OperatorCheckInCubit extends Cubit<OperatorCheckInState> {
  OperatorCheckInCubit({
    required this.getTodayDepartures,
    required this.getDepartureProgress,
    required this.scanCheckIn,
  }) : super(const OperatorCheckInInitial());

  final GetOperatorTodayDeparturesUseCase getTodayDepartures;
  final GetDepartureProgressUseCase getDepartureProgress;
  final ScanCheckInUseCase scanCheckIn;
  int _requestGeneration = 0;
  bool _scanInFlight = false;

  Future<void> loadInitial({int? preselectedScheduleId}) async {
    // Keep the selected departure and its eventual scan feedback together.
    if (isClosed || _scanInFlight) return;
    final previous = state is OperatorCheckInLoaded
        ? state as OperatorCheckInLoaded
        : null;
    if (previous?.isManualEntryActive ?? false) return;
    final switchesDeparture =
        previous != null &&
        preselectedScheduleId != null &&
        previous.selectedDeparture?.scheduleId != preselectedScheduleId;
    final generation = ++_requestGeneration;
    if (previous == null) {
      emit(const OperatorCheckInLoading());
    } else {
      emit(previous.copyWith(isRefreshing: true));
    }
    try {
      final departures = await getTodayDepartures();
      if (!_isCurrent(generation)) return;
      final previousSelection = previous?.selectedDeparture;
      if (!switchesDeparture &&
          previousSelection != null &&
          !departures.any(
            (d) => d.scheduleId == previousSelection.scheduleId,
          )) {
        // A refresh is not an operator-authorized departure/session reset.
        return;
      }
      if (departures.isEmpty) {
        emit(
          const OperatorCheckInLoaded(
            departures: [],
            selectedDeparture: null,
            progress: null,
          ),
        );
        return;
      }

      final selectedId =
          preselectedScheduleId ?? previous?.selectedDeparture?.scheduleId;
      final selected = selectedId != null
          ? departures.firstWhere(
              (d) => d.scheduleId == selectedId,
              orElse: () => departures.first,
            )
          : departures.first;

      var progress = _snapshot(selected);
      try {
        final fetched = await getDepartureProgress(selected.scheduleId);
        if (fetched.scheduleId == selected.scheduleId) progress = fetched;
      } catch (_) {
        // The departure list already supplied a matching progress snapshot.
      }
      if (!_isCurrent(generation)) return;

      final latest = state;
      final retained = latest is OperatorCheckInLoaded ? latest : previous;
      emit(
        retained?.copyWith(
              departures: departures,
              selectedDeparture: selected,
              progress: progress,
              isRefreshing: false,
              clearLastResult: switchesDeparture,
              clearLastFailure: switchesDeparture,
              scanArmed: switchesDeparture ? true : retained.scanArmed,
              scanSession: retained.scanSession + (switchesDeparture ? 1 : 0),
            ) ??
            OperatorCheckInLoaded(
              departures: departures,
              selectedDeparture: selected,
              progress: progress,
            ),
      );
    } catch (e) {
      if (!_isCurrent(generation)) return;
      if (previous != null) return; // Keep held feedback on a refresh failure.
      emit(
        OperatorCheckInError(
          e is CheckInFailure
              ? (e.message ?? 'Failed to load departures')
              : 'Failed to load departures: $e',
        ),
      );
    } finally {
      if (_isCurrent(generation)) {
        final latest = state;
        if (latest is OperatorCheckInLoaded && latest.isRefreshing) {
          emit(latest.copyWith(isRefreshing: false));
        }
      }
    }
  }

  Future<void> selectDeparture(int scheduleId) async {
    if (isClosed || _scanInFlight) return;
    final current = state;
    if (current is! OperatorCheckInLoaded ||
        current.isManualEntryActive ||
        current.isRefreshing) {
      return;
    }
    if (current.selectedDeparture?.scheduleId == scheduleId) return;
    if (!current.departures.any((d) => d.scheduleId == scheduleId)) return;

    final selected = current.departures.firstWhere(
      (d) => d.scheduleId == scheduleId,
      orElse: () => current.departures.first,
    );
    final generation = ++_requestGeneration;

    emit(
      current.copyWith(
        selectedDeparture: selected,
        progress: _snapshot(selected),
        clearLastResult: true,
        clearLastFailure: true,
        scanArmed: true,
        scanSession: current.scanSession + 1,
      ),
    );

    try {
      final progress = await getDepartureProgress(scheduleId);
      if (!_isCurrent(generation) || progress.scheduleId != scheduleId) return;
      final latest = state;
      if (latest is OperatorCheckInLoaded &&
          latest.selectedDeparture?.scheduleId == scheduleId) {
        emit(latest.copyWith(progress: progress));
      }
    } catch (_) {
      // Keep the newly selected departure's own snapshot on a read failure.
    }
  }

  Future<void> submitScan({
    String? qrContent,
    String? bookingCode,
    double? latitude,
    double? longitude,
  }) async {
    if (isClosed || _scanInFlight) return;
    final current = state;
    if (current is! OperatorCheckInLoaded) return;
    if (current.isSubmittingScan || current.isRefreshing) return;
    if (qrContent != null &&
        (!current.scanArmed || current.isManualEntryActive)) {
      return;
    }

    final schedule = current.selectedDeparture;
    if (schedule == null) return;

    _scanInFlight = true;
    // A pending pre-scan read must not replace the returned updated counts.
    ++_requestGeneration;
    emit(current.copyWith(isSubmittingScan: true, scanArmed: false));

    try {
      final result = await scanCheckIn(
        scheduleId: schedule.scheduleId,
        qrContent: qrContent,
        bookingCode: bookingCode,
        latitude: latitude,
        longitude: longitude,
      );
      if (isClosed) return;
      if (result.departure.scheduleId != schedule.scheduleId) {
        throw const CheckInFailure(kind: CheckInFailureKind.system);
      }
      final latest = state;
      if (latest is! OperatorCheckInLoaded) return;

      final scanItem = CheckInScanItem(
        code: result.ticketCode,
        passengerName: result.passengerName,
        participantCount: result.participantCount,
        timestamp: result.checkedInAtUtc,
        status: CheckInScanStatus.valid,
      );

      final updatedScans = [scanItem, ...latest.recentScans];

      emit(
        latest.copyWith(
          isSubmittingScan: false,
          lastResult: result,
          clearLastFailure: true,
          progress: result.departure,
          recentScans: updatedScans,
        ),
      );
    } on CheckInFailure catch (failure) {
      if (isClosed) return;
      final latest = state;
      if (latest is! OperatorCheckInLoaded) return;
      final uncertain =
          failure.kind == CheckInFailureKind.network ||
          failure.kind == CheckInFailureKind.system;
      final scanStatus = failure.kind == CheckInFailureKind.alreadyUsed
          ? CheckInScanStatus.alreadyUsed
          : uncertain
          ? CheckInScanStatus.notConfirmed
          : CheckInScanStatus.rejected;

      final scanItem = CheckInScanItem(
        code: failure.ticketCode ?? bookingCode ?? 'Ticket',
        passengerName: failure.passengerName ?? 'Traveler',
        participantCount: 0,
        timestamp: DateTime.now(),
        status: scanStatus,
        reason: uncertain
            ? 'Check-in not confirmed'
            : failure.message ?? _reasonFromKind(failure.kind),
      );

      final updatedScans = [scanItem, ...latest.recentScans];

      emit(
        latest.copyWith(
          isSubmittingScan: false,
          lastFailure: failure,
          clearLastResult: true,
          recentScans: updatedScans,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      final latest = state;
      if (latest is! OperatorCheckInLoaded) return;
      emit(
        latest.copyWith(
          isSubmittingScan: false,
          lastFailure: const CheckInFailure(kind: CheckInFailureKind.system),
          clearLastResult: true,
        ),
      );
    } finally {
      _scanInFlight = false;
    }
  }

  bool get canScanQr {
    final current = state;
    return !isClosed &&
        !_scanInFlight &&
        current is OperatorCheckInLoaded &&
        current.scanArmed &&
        !current.isRefreshing &&
        !current.isManualEntryActive;
  }

  void clearActiveBanner() {
    if (isClosed || _scanInFlight) return;
    final current = state;
    if (current is OperatorCheckInLoaded &&
        !current.isManualEntryActive &&
        !current.isRefreshing) {
      emit(
        current.copyWith(
          clearLastResult: true,
          clearLastFailure: true,
          scanArmed: true,
          scanSession: current.scanSession + 1,
        ),
      );
    }
  }

  bool beginManualEntry() {
    final current = state;
    if (isClosed ||
        _scanInFlight ||
        current is! OperatorCheckInLoaded ||
        current.isManualEntryActive ||
        current.isRefreshing ||
        current.selectedDeparture == null) {
      return false;
    }
    emit(current.copyWith(isManualEntryActive: true));
    return true;
  }

  void endManualEntry() {
    if (isClosed) return;
    final current = state;
    if (current is OperatorCheckInLoaded) {
      emit(current.copyWith(isManualEntryActive: false));
    }
  }

  void setCameraPermission(bool granted) {
    if (isClosed) return;
    final current = state;
    if (current is OperatorCheckInLoaded) {
      emit(current.copyWith(cameraPermissionGranted: granted));
    }
  }

  bool _isCurrent(int generation) =>
      !isClosed && generation == _requestGeneration;

  DepartureProgress _snapshot(OperatorDepartureSummary departure) =>
      DepartureProgress(
        scheduleId: departure.scheduleId,
        tourTitle: departure.tourTitle,
        startAtUtc: departure.startAtUtc,
        endAtUtc: departure.endAtUtc,
        meetingPoint: departure.meetingPoint,
        checkedInParticipants: departure.checkedInParticipants,
        totalEligibleParticipants: departure.totalEligibleParticipants,
        waitingParticipants: departure.waitingParticipants,
      );

  String _reasonFromKind(CheckInFailureKind kind) => switch (kind) {
    CheckInFailureKind.alreadyUsed => 'Ticket already checked in',
    CheckInFailureKind.departureNotToday => 'Different departure date',
    CheckInFailureKind.wrongSchedule => 'Wrong tour departure',
    CheckInFailureKind.bookingCancelled => 'Booking cancelled',
    CheckInFailureKind.bookingNotConfirmed => 'Booking unpaid',
    CheckInFailureKind.invalidQr => 'Invalid or forged QR',
    CheckInFailureKind.ticketNotFound => 'Ticket not found',
    _ => 'Check-in rejected',
  };
}
