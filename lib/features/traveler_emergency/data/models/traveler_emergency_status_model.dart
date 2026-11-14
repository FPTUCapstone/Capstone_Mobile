import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';

/// Parses `TourBookingEmergencyStatusResponse`. Identifiers and committed state
/// are required; instructions and contact may be absent.
abstract final class TravelerEmergencyStatusModel {
  static TravelerEmergencyStatus fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid emergency status.');
    }
    return TravelerEmergencyStatus(
      bookingId: _id(raw['bookingId']),
      tourScheduleId: _id(raw['tourScheduleId']),
      bookingStatus: _requiredText(raw['bookingStatus']),
      scheduleStatus: _requiredText(raw['scheduleStatus']),
      totalTicketCount: _count(raw['totalTicketCount']),
      cancelledTicketCount: _count(raw['cancelledTicketCount']),
      usedTicketCount: _count(raw['usedTicketCount']),
      action: EmergencyAction.fromWire(raw['action']),
      reasonCategory: _requiredText(raw['reasonCategory']),
      reasonDetails: _requiredText(raw['reasonDetails']),
      committedAtUtc: _requiredDate(raw['committedAtUtc']),
      immediateInstructions: _text(raw['immediateInstructions']),
      emergencyContact: _text(raw['emergencyContact']),
      acknowledgedAtUtc: _date(raw['acknowledgedAtUtc']),
      // Added later by the Backend: an older one omits both, which must not
      // hide the safety content.
      refundHandling: RefundHandling.fromWire(raw['refundHandling']),
      tourId: _optionalId(raw['tourId']),
    );
  }

  static List<TravelerEmergencyNotice> notices(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid emergency notice list.');
    }
    return raw
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid emergency notice.');
          }
          return TravelerEmergencyNotice(
            bookingId: _id(item['bookingId']),
            scheduleId: _id(item['scheduleId']),
            action: EmergencyAction.fromWire(item['action']),
            committedAtUtc: _requiredDate(item['committedAtUtc']),
            acknowledgedAtUtc: _date(item['acknowledgedAtUtc']),
          );
        })
        .toList(growable: false);
  }

  static DateTime acknowledgedAt(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid emergency acknowledgement.');
    }
    return _requiredDate(raw['acknowledgedAtUtc']);
  }

  static int _id(Object? value) {
    if (value is int && value > 0) return value;
    throw const FormatException('Invalid emergency identifier.');
  }

  static int? _optionalId(Object? value) =>
      value is int && value > 0 ? value : null;

  static int _count(Object? value) {
    if (value is int && value >= 0) return value;
    throw const FormatException('Invalid emergency count.');
  }

  static String _requiredText(Object? value) {
    final text = _text(value);
    if (text != null) return text;
    throw const FormatException('Invalid emergency text.');
  }

  static DateTime _requiredDate(Object? value) {
    final date = _date(value);
    if (date != null) return date;
    throw const FormatException('Invalid emergency date.');
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
