import 'airport.dart';

/// Directional airport connection, not a schedule or verified flown path.
class AircraftRoute {
  const AircraftRoute({required this.origin, required this.destination});
  final Airport origin;
  final Airport destination;
  String get identifier => '${origin.icao}-${destination.icao}';
  String get label => '${origin.displayCode} → ${destination.displayCode}';
  bool get hasCoordinates =>
      origin.latitude != null &&
      origin.longitude != null &&
      destination.latitude != null &&
      destination.longitude != null;
}
