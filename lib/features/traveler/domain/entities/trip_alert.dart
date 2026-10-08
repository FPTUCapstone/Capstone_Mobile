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
    this.rerouteProposalAvailable = false,
  });

  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final TripAlertType type;
  final String affectedStopName;
  final DateTime timestamp;
  final bool isDismissedFromBanner;
  final bool rerouteProposalAvailable;

  TripAlert copyWith({
    String? id,
    String? title,
    String? description,
    AlertSeverity? severity,
    TripAlertType? type,
    String? affectedStopName,
    DateTime? timestamp,
    bool? isDismissedFromBanner,
    bool? rerouteProposalAvailable,
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
      rerouteProposalAvailable:
          rerouteProposalAvailable ?? this.rerouteProposalAvailable,
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
    rerouteProposalAvailable,
  ];
}
