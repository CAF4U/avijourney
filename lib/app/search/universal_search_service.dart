import '../../domain/models/airline.dart';
import '../../domain/models/airport.dart';
import '../../domain/models/search_result.dart';
import '../../domain/models/tracked_aircraft.dart';

class UniversalSearchService {
  const UniversalSearchService();

  List<SearchResult> search({
    required String query,
    required Iterable<TrackedAircraft> aircraft,
    required Iterable<Airline> airlines,
    required Iterable<Airport> airports,
  }) {
    final tokens = _tokens(query);
    if (tokens.isEmpty) return const [];
    final results = <SearchResult>[];
    final airlineList = airlines.toList(growable: false);
    final routeKeys = <String>{};

    for (final tracked in aircraft) {
      final flight = tracked.flight;
      final route = tracked.route;
      final callsign = tracked.state.callsign.trim().toUpperCase();
      final airline = _airlineFor(callsign, airlineList);
      final origin = flight?.origin ?? route?.origin;
      final destination = flight?.destination ?? route?.destination;
      final routeLabel = origin != null && destination != null
          ? '${origin.displayCode} -> ${destination.displayCode}'
          : null;
      final common = <String?>[
        callsign,
        tracked.state.icao24,
        tracked.identity?.registration,
        tracked.identity?.model,
        tracked.identity?.typeCode,
        tracked.identity?.operatorName,
        airline?.name,
        airline?.iataCode,
        airline?.icaoCode,
        flight?.commercialFlightNumber,
        origin?.iata,
        origin?.icao,
        origin?.name,
        origin?.city,
        destination?.iata,
        destination?.icao,
        destination?.name,
        destination?.city,
      ];
      if (_matches(tokens, common)) {
        results.add(SearchResult(
          type: SearchResultType.aircraft,
          identifier: tracked.state.icao24,
          title: tracked.identity?.registration ?? tracked.primaryIdentifier,
          subtitle: [
            tracked.identity?.model ?? tracked.identity?.typeCode,
            airline?.name ?? tracked.identity?.operatorName,
          ].whereType<String>().join(' · '),
          matchReason: 'Matched live aircraft identity, operator or route',
          value: tracked,
        ));
        results.add(SearchResult(
          type: SearchResultType.flight,
          identifier: flight?.primaryIdentifier ?? callsign,
          title: flight?.primaryIdentifier ?? callsign,
          subtitle: [airline?.name, routeLabel].whereType<String>().join(' · '),
          matchReason: flight?.isCommercialIdentityVerified == true
              ? 'Verified commercial flight identity'
              : 'Matched operational callsign or known route',
          value: tracked,
        ));
      }
      if (routeLabel != null && _matches(tokens, common)) {
        final key = routeLabel.toUpperCase();
        if (routeKeys.add(key)) {
          results.add(SearchResult(
            type: SearchResultType.route,
            identifier: key,
            title: routeLabel,
            subtitle: airline?.name ?? 'Known live route',
            matchReason: 'Matched origin and destination',
            value: tracked,
          ));
        }
      }
    }

    for (final airline in airlineList) {
      if (_matches(
          tokens, [airline.name, airline.iataCode, airline.icaoCode])) {
        results.add(SearchResult(
          type: SearchResultType.airline,
          identifier: airline.identifier,
          title: airline.name,
          subtitle: [airline.iataCode, airline.icaoCode]
              .whereType<String>()
              .join(' · '),
          matchReason: 'Matched airline name or code',
          value: airline,
        ));
      }
    }
    for (final airport in airports) {
      if (_matches(tokens,
              [airport.iata, airport.icao, airport.name, airport.city]) ||
          [
            airport.iata,
            airport.icao,
            airport.name,
            airport.city
          ].whereType<String>().any((field) => field
              .toUpperCase()
              .replaceAll(RegExp(r'\s+'), '')
              .contains(query.toUpperCase().replaceAll(RegExp(r'\s+'), '')))) {
        results.add(SearchResult(
          type: SearchResultType.airport,
          identifier: airport.icao,
          title: '${airport.displayCode} · ${airport.name}',
          subtitle:
              [airport.city, airport.country].whereType<String>().join(', '),
          matchReason: 'Matched airport code, name or city',
          value: airport,
        ));
      }
    }
    return results;
  }

  static List<String> _tokens(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[-–—>]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);

  static bool _matches(List<String> tokens, Iterable<String?> fields) {
    final haystack = fields
        .whereType<String>()
        .map((field) => field.toUpperCase().replaceAll(RegExp(r'\s+'), ' '))
        .join(' ');
    return tokens.every(haystack.contains);
  }

  static Airline? _airlineFor(String callsign, List<Airline> airlines) {
    for (final airline in airlines) {
      final icao = airline.icaoCode;
      if (icao != null && callsign.startsWith(icao)) return airline;
    }
    return null;
  }
}
