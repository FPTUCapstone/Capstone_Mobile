import 'package:equatable/equatable.dart';

/// Visual presentation severity for in-trip banners and alert history.
enum AlertSeverity { info, warning, critical }

/// Semantic presentation & demo categorization for in-trip disruption alerts.
///
/// NOTE (SRS_ALERT_TAXONOMY_CONFLICT):
/// This enum is strictly a Mobile UI presentation model for rendering icons
/// and sample demo fixtures. It is NOT a frozen Backend production contract or DTO.
/// The final production backend event taxonomy will be mapped to UI semantics
/// once real-time alert contracts are finalized.
enum TripAlertType { weather, delay, closure, deviation }

enum WeatherBasis { forecastAtPlannedTime, currentAtDestination, officialEvent }

final class TripAlert extends Equatable {
  const TripAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.type,
    required this.affectedStopName,
    required this.timestamp,
    this.isDismissedFromBanner = false,
    this.messageCode = '',
    this.affectedItemId,
    this.plannedDeparture,
    this.resolvedAt,
    this.isRead = false,
    this.reroutingProposalId,
    this.weatherBasis,
    this.weatherAtUtc,
    this.rainIntensityMmPerHour,
    this.canSkipAffectedStop = false,
  });

  static const stopOverstayMessageCode = 'trip_alert.stop_overstay';
  static const localOverstayIdPrefix = 'local-overstay:';

  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final TripAlertType type;
  final String affectedStopName;
  final DateTime timestamp;
  final bool isDismissedFromBanner;
  final String messageCode;
  final int? affectedItemId;
  final DateTime? plannedDeparture;
  final DateTime? resolvedAt;
  final bool isRead;
  final int? reroutingProposalId;
  final WeatherBasis? weatherBasis;
  final DateTime? weatherAtUtc;
  final double? rainIntensityMmPerHour;
  final bool canSkipAffectedStop;

  bool get isResolved => resolvedAt != null;
  bool get isOverstay => messageCode == stopOverstayMessageCode;
  bool get isLocalOverstay => id.startsWith(localOverstayIdPrefix);

  /// The Backend attached a UC-15 re-routing proposal to this alert.
  bool get rerouteProposalAvailable => reroutingProposalId != null;

  TripAlert copyWith({
    String? id,
    String? title,
    String? description,
    AlertSeverity? severity,
    TripAlertType? type,
    String? affectedStopName,
    DateTime? timestamp,
    bool? isDismissedFromBanner,
    String? messageCode,
    int? affectedItemId,
    DateTime? plannedDeparture,
    DateTime? resolvedAt,
    bool? isRead,
    int? reroutingProposalId,
    WeatherBasis? weatherBasis,
    DateTime? weatherAtUtc,
    double? rainIntensityMmPerHour,
    bool? canSkipAffectedStop,
  }) {
    return TripAlert(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      type: type ?? this.type,
      affectedStopName: affectedStopName ?? this.affectedStopName,
      timestamp: timestamp ?? this.timestamp,
      isDismissedFromBanner:
          isDismissedFromBanner ?? this.isDismissedFromBanner,
      messageCode: messageCode ?? this.messageCode,
      affectedItemId: affectedItemId ?? this.affectedItemId,
      plannedDeparture: plannedDeparture ?? this.plannedDeparture,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isRead: isRead ?? this.isRead,
      reroutingProposalId: reroutingProposalId ?? this.reroutingProposalId,
      weatherBasis: weatherBasis ?? this.weatherBasis,
      weatherAtUtc: weatherAtUtc ?? this.weatherAtUtc,
      rainIntensityMmPerHour:
          rainIntensityMmPerHour ?? this.rainIntensityMmPerHour,
      canSkipAffectedStop: canSkipAffectedStop ?? this.canSkipAffectedStop,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    severity,
    type,
    affectedStopName,
    timestamp,
    isDismissedFromBanner,
    messageCode,
    affectedItemId,
    plannedDeparture,
    resolvedAt,
    isRead,
    reroutingProposalId,
    weatherBasis,
    weatherAtUtc,
    rainIntensityMmPerHour,
    canSkipAffectedStop,
  ];
}
