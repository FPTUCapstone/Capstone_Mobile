import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';

sealed class OperatorCheckInState extends Equatable {
  const OperatorCheckInState();

  @override
  List<Object?> get props => [];
}

final class OperatorCheckInInitial extends OperatorCheckInState {
  const OperatorCheckInInitial();
}

final class OperatorCheckInLoading extends OperatorCheckInState {
  const OperatorCheckInLoading();
}

final class OperatorCheckInLoaded extends OperatorCheckInState {
  const OperatorCheckInLoaded({
    required this.departures,
    this.selectedDeparture,
    this.progress,
    this.recentScans = const [],
    this.isSubmittingScan = false,
    this.lastResult,
    this.lastFailure,
    this.cameraPermissionGranted = true,
  });

  final List<OperatorDepartureSummary> departures;
  final OperatorDepartureSummary? selectedDeparture;
  final DepartureProgress? progress;
  final List<CheckInScanItem> recentScans;
  final bool isSubmittingScan;
  final CheckInResult? lastResult;
  final CheckInFailure? lastFailure;
  final bool cameraPermissionGranted;

  OperatorCheckInLoaded copyWith({
    List<OperatorDepartureSummary>? departures,
    OperatorDepartureSummary? selectedDeparture,
    DepartureProgress? progress,
    List<CheckInScanItem>? recentScans,
    bool? isSubmittingScan,
    CheckInResult? lastResult,
    bool clearLastResult = false,
    CheckInFailure? lastFailure,
    bool clearLastFailure = false,
    bool? cameraPermissionGranted,
  }) {
    return OperatorCheckInLoaded(
      departures: departures ?? this.departures,
      selectedDeparture: selectedDeparture ?? this.selectedDeparture,
      progress: progress ?? this.progress,
      recentScans: recentScans ?? this.recentScans,
      isSubmittingScan: isSubmittingScan ?? this.isSubmittingScan,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      lastFailure: clearLastFailure ? null : (lastFailure ?? this.lastFailure),
      cameraPermissionGranted:
          cameraPermissionGranted ?? this.cameraPermissionGranted,
    );
  }

  @override
  List<Object?> get props => [
    departures,
    selectedDeparture,
    progress,
    recentScans,
    isSubmittingScan,
    lastResult,
    lastFailure,
    cameraPermissionGranted,
  ];
}

final class OperatorCheckInError extends OperatorCheckInState {
  const OperatorCheckInError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
