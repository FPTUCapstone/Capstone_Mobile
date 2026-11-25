import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';

/// Parses the UC-15 `GET .../rerouting-proposals/{id}` detail response.
abstract final class RerouteProposalModel {
  static RerouteProposal fromJson(Map<String, dynamic> json) {
    final reason = _map(json, 'reason');
    return RerouteProposal(
      proposalId: _int(json, 'proposalId'),
      incidentId: _int(json, 'incidentId'),
      status: _status(json['status']),
      reason: RerouteReason(
        code: _string(reason, 'code'),
        strategy: _string(reason, 'strategy'),
        affectedPoiName: reason['affectedPoiName'] as String?,
      ),
      currentStops: _list(json, 'currentStops').map(_stop).toList(),
      proposedStops: _list(
        json,
        'proposedStops',
      ).map((stop) => _stop(stop, withChange: true)).toList(),
      removedStops: _list(
        json,
        'removedStops',
      ).map((stop) => _string(stop, 'name')).toList(),
      affectedStops: _list(
        json,
        'affectedStops',
      ).map((stop) => _string(stop, 'name')).toList(),
      travelTimeDiffMinutes: _int(json, 'travelTimeDiffMinutes'),
      arrivalTimeDiffMinutes: _int(json, 'arrivalTimeDiffMinutes'),
      proposedAt: _date(json, 'proposedAtUtc'),
      expiresAt: _date(json, 'expiresAtUtc'),
      decidedAt: _optionalDate(json['decidedAtUtc']),
    );
  }

  static RerouteStop _stop(
    Map<String, dynamic> json, {
    bool withChange = false,
  }) => RerouteStop(
    name: _string(json, 'name'),
    plannedArrival: _date(json, 'plannedArrivalUtc'),
    plannedDeparture: _date(json, 'plannedDepartureUtc'),
    isMandatory: json['isMandatory'] == true,
    change: withChange ? _change(json['change']) : null,
  );

  static RerouteStatus _status(Object? value) => switch (value) {
    'Proposed' => RerouteStatus.pending,
    'Accepted' => RerouteStatus.accepted,
    'Rejected' => RerouteStatus.declined,
    'Expired' => RerouteStatus.expired,
    _ => throw FormatException('Unsupported re-routing status: $value'),
  };

  static RerouteStopChange _change(Object? value) => switch (value) {
    'Kept' => RerouteStopChange.kept,
    'Added' => RerouteStopChange.added,
    'Moved' => RerouteStopChange.moved,
    _ => throw FormatException('Unsupported re-routing change: $value'),
  };

  static Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    throw FormatException('Missing re-routing object: $key');
  }

  static List<Map<String, dynamic>> _list(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! List) throw FormatException('Missing re-routing list: $key');
    return [
      for (final item in value)
        if (item is Map<String, dynamic>)
          item
        else
          throw FormatException('Invalid re-routing item in $key'),
    ];
  }

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException('Missing re-routing text: $key');
  }

  static int _int(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    throw FormatException('Missing re-routing number: $key');
  }

  static DateTime _date(Map<String, dynamic> json, String key) =>
      DateTime.parse(_string(json, key)).toUtc();

  static DateTime? _optionalDate(Object? value) =>
      value is String ? DateTime.parse(value).toUtc() : null;
}
