import 'airline.dart';
import 'airport.dart';
import 'tracked_aircraft.dart';

enum AirportDirection { either, origin, destination }

/// A local display filter. It never changes the acquisition area or verifies
/// commercial identity. Unknown route/operator fields do not match.
class AircraftFilter {
  const AircraftFilter(
      {required this.label,
      this.query,
      this.icao24,
      this.airline,
      this.airport,
      this.direction = AirportDirection.either,
      this.routeOrigin,
      this.routeDestination});

  final String label;
  final String? query;
  final String? icao24;
  final Airline? airline;
  final Airport? airport;
  final AirportDirection direction;
  final Airport? routeOrigin;
  final Airport? routeDestination;

  bool matches(TrackedAircraft aircraft, {required bool matchesQuery}) {
    if (query != null) return matchesQuery;
    if (icao24 != null) {
      return aircraft.state.icao24.toUpperCase() == icao24!.toUpperCase();
    }
    final flight = aircraft.flight;
    final origin = flight?.origin ?? aircraft.route?.origin;
    final destination = flight?.destination ?? aircraft.route?.destination;
    if (airport != null) {
      return switch (direction) {
        AirportDirection.origin => _sameAirport(origin, airport),
        AirportDirection.destination => _sameAirport(destination, airport),
        AirportDirection.either =>
          _sameAirport(origin, airport) || _sameAirport(destination, airport),
      };
    }
    if (routeOrigin != null && routeDestination != null) {
      return _sameAirport(origin, routeOrigin) &&
          _sameAirport(destination, routeDestination);
    }
    final selectedAirline = airline;
    if (selectedAirline == null) return true;
    final icao = selectedAirline.icaoCode?.toUpperCase();
    final iata = selectedAirline.iataCode?.toUpperCase();
    final callsign = aircraft.state.callsign.trim().toUpperCase();
    return (icao != null &&
            icao.isNotEmpty &&
            (flight?.airlineIcaoCode?.toUpperCase() == icao ||
                callsign.startsWith(icao))) ||
        (iata != null &&
            iata.isNotEmpty &&
            flight?.airlineIataCode?.toUpperCase() == iata) ||
        aircraft.identity?.operatorName?.toUpperCase() ==
            selectedAirline.name.toUpperCase() ||
        flight?.airlineName?.toUpperCase() ==
            selectedAirline.name.toUpperCase();
  }

  static bool _sameAirport(Airport? a, Airport? b) =>
      a != null && b != null && a.icao.toUpperCase() == b.icao.toUpperCase();
}
