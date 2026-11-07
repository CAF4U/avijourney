enum AircraftAlertKind {
  detected,
  squawk7600,
  squawk7700,
  takeoffInferred,
  landingInferred
}

class AircraftAlert {
  const AircraftAlert(
      {required this.id,
      required this.icao24,
      required this.identifier,
      required this.kind,
      required this.occurredAt,
      required this.message,
      required this.detail});
  final String id;
  final String icao24;
  final String identifier;
  final AircraftAlertKind kind;
  final DateTime occurredAt;
  final String message;
  final String detail;
}
