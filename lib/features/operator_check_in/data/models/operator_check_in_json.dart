import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';

final class OperatorCheckInJson {
  const OperatorCheckInJson._();

  static DepartureProgress departureProgress(dynamic json) {
    final map = _asMap(json);
    return DepartureProgress(
      scheduleId: _asInt(map['scheduleId'] ?? map['ScheduleId']),
      tourTitle: _asString(map['tourTitle'] ?? map['TourTitle']),
      startAtUtc: _asDateTime(map['startAtUtc'] ?? map['StartAtUtc']),
      endAtUtc: _asDateTime(map['endAtUtc'] ?? map['EndAtUtc']),
      meetingPoint: (map['meetingPoint'] ?? map['MeetingPoint']) as String?,
      checkedInParticipants:
          _asInt(map['checkedInParticipants'] ?? map['CheckedInParticipants']),
      totalEligibleParticipants: _asInt(
          map['totalEligibleParticipants'] ?? map['TotalEligibleParticipants']),
      waitingParticipants:
          _asInt(map['waitingParticipants'] ?? map['WaitingParticipants']),
    );
  }

  static OperatorDepartureSummary departureSummary(dynamic json) {
    final map = _asMap(json);
    return OperatorDepartureSummary(
      scheduleId: _asInt(map['scheduleId'] ?? map['ScheduleId']),
      tourId: _asInt(map['tourId'] ?? map['TourId']),
      tourTitle: _asString(map['tourTitle'] ?? map['TourTitle']),
      startAtUtc: _asDateTime(map['startAtUtc'] ?? map['StartAtUtc']),
      endAtUtc: _asDateTime(map['endAtUtc'] ?? map['EndAtUtc']),
      meetingPoint: (map['meetingPoint'] ?? map['MeetingPoint']) as String?,
      status: _asString(map['status'] ?? map['Status'] ?? 'Scheduled'),
      checkedInParticipants:
          _asInt(map['checkedInParticipants'] ?? map['CheckedInParticipants']),
      totalEligibleParticipants: _asInt(
          map['totalEligibleParticipants'] ?? map['TotalEligibleParticipants']),
      waitingParticipants:
          _asInt(map['waitingParticipants'] ?? map['WaitingParticipants']),
    );
  }

  static List<OperatorDepartureSummary> departureSummaryList(dynamic json) {
    if (json is! List) return const [];
    return json.map(departureSummary).toList();
  }

  static CheckInResult checkInResult(dynamic json) {
    final map = _asMap(json);
    return CheckInResult(
      ticketCode: _asString(map['ticketCode'] ?? map['TicketCode']),
      bookingCode: _asString(map['bookingCode'] ?? map['BookingCode']),
      passengerName: _asString(map['passengerName'] ?? map['PassengerName']),
      participantCount:
          _asInt(map['participantCount'] ?? map['ParticipantCount']),
      checkedInAtUtc: _asDateTime(map['checkedInAtUtc'] ?? map['CheckedInAtUtc']),
      departure: departureProgress(map['departure'] ?? map['Departure']),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Expected JSON object.');
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static String _asString(dynamic value) {
    if (value is String) return value;
    return value?.toString() ?? '';
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    return DateTime.now().toUtc();
  }
}
