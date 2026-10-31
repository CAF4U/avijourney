import 'dart:math' as math;
import '../../domain/models/airport.dart';
import '../../domain/models/aircraft_filter.dart';
import '../../domain/models/tracked_aircraft.dart';

enum AirportTraffic { arrivals, departures, ground }

bool matchesAirportTraffic(
    TrackedAircraft aircraft, Airport airport, AirportTraffic traffic) {
  if (traffic != AirportTraffic.ground) {
    return AircraftFilter(
            label: 'Airport traffic',
            airport: airport,
            direction: traffic == AirportTraffic.arrivals
                ? AirportDirection.destination
                : AirportDirection.origin)
        .matches(aircraft, matchesQuery: false);
  }
  if (!aircraft.state.onGround ||
      airport.latitude == null ||
      airport.longitude == null) return false;
  double radians(double degrees) => degrees * math.pi / 180;
  final lat1 = radians(airport.latitude!);
  final lat2 = radians(aircraft.state.latitude);
  final dlat = lat2 - lat1;
  final dlon = radians(aircraft.state.longitude - airport.longitude!);
  final a = math.pow(math.sin(dlat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dlon / 2), 2);
  final distanceNm = 3440.065 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  return distanceNm <= 3;
}
