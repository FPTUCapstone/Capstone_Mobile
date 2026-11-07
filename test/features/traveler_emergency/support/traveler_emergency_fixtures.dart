import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';

Map<String, dynamic> stoppedStatusJson() => {
  'bookingId': 42,
  'tourScheduleId': 31,
  'bookingStatus': 'Interrupted',
  'scheduleStatus': 'EmergencyStopped',
  'totalTicketCount': 3,
  'cancelledTicketCount': 3,
  'usedTicketCount': 0,
  'action': 'EmergencyStopActive',
  'reasonCategory': 'SafetyIncident',
  'reasonDetails': 'Road closed',
  'immediateInstructions': 'Stay at the shelter.',
  'emergencyContact': 'Hotline +84 900 000 000',
  'committedAtUtc': '2026-11-10T02:00:00Z',
  'acknowledgedAtUtc': null,
};

extension TravelerEmergencyFixture on TravelerEmergencyStatus {
  static TravelerEmergencyStatus build({
    EmergencyAction action = EmergencyAction.emergencyStop,
    String? emergencyContact = 'Hotline +84 900 000 000',
    String? immediateInstructions = 'Stay at the shelter.',
    DateTime? acknowledgedAtUtc,
  }) => TravelerEmergencyStatus(
    bookingId: 42,
    tourScheduleId: 31,
    bookingStatus: 'Interrupted',
    scheduleStatus: action == EmergencyAction.emergencyStop
        ? 'EmergencyStopped'
        : 'Cancelled',
    totalTicketCount: 3,
    cancelledTicketCount: 3,
    usedTicketCount: 0,
    action: action,
    reasonCategory: 'SafetyIncident',
    reasonDetails: 'Road closed',
    immediateInstructions: immediateInstructions,
    emergencyContact: emergencyContact,
    committedAtUtc: DateTime.utc(2026, 11, 10, 2),
    acknowledgedAtUtc: acknowledgedAtUtc,
  );
}
