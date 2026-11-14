/// Sanitized copies of the Backend UC-70 payloads (no real people or secrets).
const validImpactVersion =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
const otherImpactVersion =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

Map<String, dynamic> reviewJson({
  int id = 7,
  String status = 'PendingAcknowledgement',
  String scheduleStatus = 'Scheduled',
}) => {
  'id': id,
  'tourScheduleId': 31,
  'tourId': 12,
  'tourTitle': 'Hue heritage day tour',
  'scheduleStartAtUtc': '2026-11-10T01:00:00Z',
  'scheduleEndAtUtc': '2026-11-10T10:00:00Z',
  'scheduleStatus': scheduleStatus,
  'provider': 'TomorrowIo',
  'providerEventId': 'evt-1',
  'eventType': 'Storm',
  'severity': 'Severe',
  'description': 'Storm warning',
  'validFromUtc': '2026-11-10T00:00:00Z',
  'validToUtc': '2026-11-10T12:00:00Z',
  'originalAuthority': 'NCHMF',
  'officialVietnamRiskLevel': 3,
  'verifiedDirective': 'TravelProhibition',
  'affectedAreaSummary': 'Thua Thien Hue',
  'isWithdrawn': false,
  'status': status,
  'urgentNoticeSentAtUtc': '2026-11-09T08:00:00Z',
  'acknowledgementDeadlineUtc': '2026-11-09T09:00:00Z',
  'acknowledgedAtUtc': null,
  'acknowledgedByOperatorId': null,
  'escalatedAtUtc': null,
  'escalationContact': null,
  'immediateInstructions': null,
  'createdAtUtc': '2026-11-09T08:00:00Z',
};

Map<String, dynamic> impactJson({
  String action = 'CancelBeforeDeparture',
  String version = validImpactVersion,
  bool hasUnverifiedSessions = false,
}) => {
  'tourId': 12,
  'scheduleId': 31,
  'action': action,
  'scheduleStatus': 'Scheduled',
  'paidBookingCount': 2,
  'unpaidBookingCount': 1,
  'totalPassengerCount': 5,
  'activeSessionCount': 0,
  'unusedTicketCount': 5,
  'hasUnverifiedSessions': hasUnverifiedSessions,
  'impactVersion': version,
};

Map<String, dynamic> actionResultJson({
  String action = 'EmergencyStopActive',
  int refundsSubmitted = 0,
}) => {
  'operationId': 90,
  'tourScheduleId': 31,
  'action': action,
  'scheduleStatus': 'EmergencyStopped',
  'affectedBookingCount': 3,
  'committedAtUtc': '2026-11-10T02:00:00Z',
  'refundsSubmitted': refundsSubmitted,
};

Map<String, dynamic> problem(String errorCode, {String title = 'Rejected'}) => {
  'title': title,
  'errorCode': errorCode,
};
