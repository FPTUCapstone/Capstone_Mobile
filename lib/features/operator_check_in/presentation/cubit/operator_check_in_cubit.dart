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
    final generation = ++_requestGeneration;
    emit(const OperatorCheckInLoading());
    try {
      final departures = await getTodayDepartures();
      if (!_isCurrent(generation)) return;
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

      final selected = preselectedScheduleId != null
          ? departures.firstWhere(
              (d) => d.scheduleId == preselectedScheduleId,
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

      emit(
        OperatorCheckInLoaded(
          departures: departures,
          selectedDeparture: selected,
          progress: progress,
        ),
      );
    } catch (e) {
      if (!_isCurrent(generation)) return;
      emit(
        OperatorCheckInError(
          e is CheckInFailure
              ? (e.message ?? 'Failed to load departures')
              : 'Failed to load departures: $e',
        ),
      );
    }
  }

  Future<void> selectDeparture(int scheduleId) async {
    if (isClosed || _scanInFlight) return;
    final current = state;
    if (current is! OperatorCheckInLoaded) return;
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
    if (current.isSubmittingScan) return; // Debounce guard

    final schedule = current.selectedDeparture;
    if (schedule == null) return;

    _scanInFlight = true;
    // A pending pre-scan read must not replace the returned updated counts.
    ++_requestGeneration;
    emit(current.copyWith(isSubmittingScan: true));

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
        timestamp: DateTime.now(),
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
      final scanStatus = failure.kind == CheckInFailureKind.alreadyUsed
          ? CheckInScanStatus.alreadyUsed
          : CheckInScanStatus.rejected;

      final scanItem = CheckInScanItem(
        code: failure.ticketCode ?? bookingCode ?? 'Ticket',
        passengerName: failure.passengerName ?? 'Traveler',
        participantCount: 0,
        timestamp: DateTime.now(),
        status: scanStatus,
        reason: failure.message ?? _reasonFromKind(failure.kind),
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
    } catch (e) {
      if (isClosed) return;
      final latest = state;
      if (latest is! OperatorCheckInLoaded) return;
      emit(
        latest.copyWith(
          isSubmittingScan: false,
          lastFailure: CheckInFailure(
            kind: CheckInFailureKind.system,
            message: e.toString(),
          ),
          clearLastResult: true,
        ),
      );
    } finally {
      _scanInFlight = false;
    }
  }

  void clearActiveBanner() {
    if (isClosed) return;
    final current = state;
    if (current is OperatorCheckInLoaded) {
      emit(current.copyWith(clearLastResult: true, clearLastFailure: true));
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
