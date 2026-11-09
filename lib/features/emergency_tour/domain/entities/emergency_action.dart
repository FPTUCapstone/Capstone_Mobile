/// The terminal decision of a UC-70 emergency operation, shared by the Operator
/// and Traveler surfaces. [unknown] keeps a future Backend value from being
/// mistaken for either real action.
enum EmergencyAction {
  cancelBeforeDeparture,
  emergencyStop,
  unknown;

  static EmergencyAction fromWire(Object? value) => switch (value) {
    'CancelBeforeDeparture' => cancelBeforeDeparture,
    'EmergencyStopActive' => emergencyStop,
    _ => unknown,
  };
}
