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

  Future<void> loadInitial({int? preselectedScheduleId}) async {
    emit(const OperatorCheckInLoading());
    try {
      final departures = await getTodayDepartures();
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

      DepartureProgress? progress;
      try {
        progress = await getDepartureProgress(selected.scheduleId);
      } catch (_) {
        progress = DepartureProgress(
          scheduleId: selected.scheduleId,
          tourTitle: selected.tourTitle,
          startAtUtc: selected.startAtUtc,
          endAtUtc: selected.endAtUtc,
          meetingPoint: selected.meetingPoint,
          checkedInParticipants: selected.checkedInParticipants,
          totalEligibleParticipants: selected.totalEligibleParticipants,
          waitingParticipants: selected.waitingParticipants,
        );
      }

      emit(
        OperatorCheckInLoaded(
          departures: departures,
          selectedDeparture: selected,
          progress: progress,
        ),
      );
    } catch (e) {
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
    final current = state;
    if (current is! OperatorCheckInLoaded) return;

    final selected = current.departures.firstWhere(
      (d) => d.scheduleId == scheduleId,
      orElse: () => current.departures.first,
    );

    emit(
      current.copyWith(
        selectedDeparture: selected,
        clearLastResult: true,
        clearLastFailure: true,
      ),
    );

    try {
      final progress = await getDepartureProgress(scheduleId);
      emit((state as OperatorCheckInLoaded).copyWith(progress: progress));
    } catch (_) {}
  }

  Future<void> submitScan({
    String? qrContent,
    String? bookingCode,
    double? latitude,
    double? longitude,
  }) async {
    final current = state;
    if (current is! OperatorCheckInLoaded) return;
    if (current.isSubmittingScan) return; // Debounce guard

    final schedule = current.selectedDeparture;
    if (schedule == null) return;

    emit(current.copyWith(isSubmittingScan: true));

    try {
      final result = await scanCheckIn(
        scheduleId: schedule.scheduleId,
        qrContent: qrContent,
        bookingCode: bookingCode,
        latitude: latitude,
        longitude: longitude,
      );

      final scanItem = CheckInScanItem(
        code: result.ticketCode,
        passengerName: result.passengerName,
        participantCount: result.participantCount,
        timestamp: DateTime.now(),
        status: CheckInScanStatus.valid,
      );

      final updatedScans = [scanItem, ...current.recentScans];

      emit(
        current.copyWith(
          isSubmittingScan: false,
          lastResult: result,
          clearLastFailure: true,
          progress: result.departure,
          recentScans: updatedScans,
        ),
      );
    } on CheckInFailure catch (failure) {
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

      final updatedScans = [scanItem, ...current.recentScans];

      emit(
        current.copyWith(
          isSubmittingScan: false,
          lastFailure: failure,
          clearLastResult: true,
          recentScans: updatedScans,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          isSubmittingScan: false,
          lastFailure: CheckInFailure(
            kind: CheckInFailureKind.system,
            message: e.toString(),
          ),
          clearLastResult: true,
        ),
      );
    }
  }

  void clearActiveBanner() {
    final current = state;
    if (current is OperatorCheckInLoaded) {
      emit(current.copyWith(clearLastResult: true, clearLastFailure: true));
    }
  }

  void setCameraPermission(bool granted) {
    final current = state;
    if (current is OperatorCheckInLoaded) {
      emit(current.copyWith(cameraPermissionGranted: granted));
    }
  }

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
