import 'package:avijourney/app/search/universal_search_service.dart';
import 'package:avijourney/data/local/static_airline_catalog.dart';
import 'package:avijourney/data/local/static_airport_search_provider.dart';
import 'package:avijourney/domain/models/aircraft_identity.dart';
import 'package:avijourney/domain/models/aircraft_state.dart';
import 'package:avijourney/domain/models/flight.dart';
import 'package:avijourney/domain/models/search_result.dart';
import 'package:avijourney/domain/models/tracked_aircraft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lhr = StaticAirportSearchProvider.airports;
  final heathrow = lhr.firstWhere((airport) => airport.iata == 'LHR');
  final gatwick = lhr.firstWhere((airport) => airport.iata == 'LGW');
  final aircraft = TrackedAircraft(
    state: AircraftState(
      icao24: '40621D',
      callsign: 'BAW283',
      latitude: 51.5,
      longitude: -.2,
      altitudeFeet: 28000,
      groundSpeedKnots: 420,
      trackDegrees: 270,
      verticalRateFeetPerMinute: 0,
      observedAt: DateTime.utc(2026),
    ),
    identity: const AircraftIdentity(
      icao24: '40621D',
      registration: 'G-XLEA',
      model: 'Airbus A380-800',
      operatorName: 'British Airways',
    ),
    flight: Flight(
      operationalCallsign: 'BAW283',
      commercialFlightNumber: 'BA283',
      airlineIataCode: 'BA',
      airlineIcaoCode: 'BAW',
      airlineName: 'British Airways',
      origin: heathrow,
      destination: gatwick,
      verificationState: FlightVerificationState.verified,
    ),
  );

  List<SearchResult> search(String query) =>
      const UniversalSearchService().search(
        query: query,
        aircraft: [aircraft],
        airlines: StaticAirlineCatalog.entries,
        airports: StaticAirportSearchProvider.airports,
      );

  test('searches callsign and verified commercial number case-insensitively',
      () {
    expect(search(' baw283 ').where((r) => r.type == SearchResultType.flight),
        isNotEmpty);
    expect(search('ba283').where((r) => r.type == SearchResultType.flight),
        isNotEmpty);
  });

  test('searches registration and aircraft type', () {
    expect(search('g-xlea'), isNotEmpty);
    expect(search('  a380 '), isNotEmpty);
  });

  test('searches airline, route, airport and combinations', () {
    expect(search('British Airways'), isNotEmpty);
    expect(search('LHR -> LGW').where((r) => r.type == SearchResultType.route),
        isNotEmpty);
    expect(search('Heathrow').where((r) => r.type == SearchResultType.airport),
        isNotEmpty);
    expect(search('British Airways LHR LGW'), isNotEmpty);
    expect(search('A380 British Airways'), isNotEmpty);
  });
}
