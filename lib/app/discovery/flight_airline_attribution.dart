import '../../domain/models/airline.dart';
import '../../domain/models/flight.dart';
import '../../domain/models/tracked_aircraft.dart';

class FlightAirlineAttribution {
  const FlightAirlineAttribution(
      {this.airline, required this.basis, this.fromCallsign = false});
  final Airline? airline;
  final String basis;
  final bool fromCallsign;
  String get name => airline?.name ?? 'Unavailable';
  String get cardLabel => '$name${fromCallsign ? ' (callsign)' : ''}';
}

/// Flight airline and airframe operator are deliberately independent. A
/// callsign association is reference metadata, never a verified marketing
/// carrier or a commercial flight-number conversion.
FlightAirlineAttribution resolveFlightAirline(
    TrackedAircraft aircraft, Iterable<Airline> catalogue) {
  final flight = aircraft.flight;
  final reportedName = flight?.airlineName?.trim();
  final source = flight?.source;
  if (reportedName != null && reportedName.isNotEmpty) {
    return FlightAirlineAttribution(
        airline: Airline(
            name: reportedName,
            iataCode: flight?.airlineIataCode,
            icaoCode: flight?.airlineIcaoCode,
            source: flight?.source),
        basis:
            '${flight?.verificationState == FlightVerificationState.verified ? 'Verified flight data' : 'Reported flight data · unverified'}'
            '${source == null ? '' : ' · $source'}');
  }
  final callsign = aircraft.state.callsign.trim().toUpperCase();
  if (RegExp(r'^[A-Z]{3}[A-Z0-9]+$').hasMatch(callsign)) {
    final code = callsign.substring(0, 3);
    final matches =
        catalogue.where((a) => a.icaoCode?.toUpperCase() == code).toList();
    if (matches.length == 1) {
      return FlightAirlineAttribution(
          airline: matches.single,
          fromCallsign: true,
          basis: '$code callsign association · marketing carrier unverified');
    }
  }
  return const FlightAirlineAttribution(
      basis: 'No reported flight airline or unique callsign association');
}
