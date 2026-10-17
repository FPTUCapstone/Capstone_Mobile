/// Matches the Backend's commerce.BookingParticipants.participant_type values exactly
/// (UC-27 spec §3). Server-side pricing depends on this value (BR-63).
enum ParticipantType {
  adult,
  child,
  infant;

  /// Wire value sent to and received from the Backend (PascalCase).
  String toWire() => switch (this) {
    ParticipantType.adult => 'Adult',
    ParticipantType.child => 'Child',
    ParticipantType.infant => 'Infant',
  };

  static ParticipantType fromWire(String value) => switch (value) {
    'Adult' => ParticipantType.adult,
    'Child' => ParticipantType.child,
    'Infant' => ParticipantType.infant,
    _ => throw FormatException('Unknown participantType: $value'),
  };
}
