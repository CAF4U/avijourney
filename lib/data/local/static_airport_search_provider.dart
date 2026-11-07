import '../../domain/models/airport.dart';
import '../../domain/providers/airport_search_provider.dart';

class StaticAirportSearchProvider implements AirportSearchProvider {
  const StaticAirportSearchProvider();

  static const airports = <Airport>[
    Airport(
        icao: 'EGLL',
        iata: 'LHR',
        name: 'London Heathrow Airport',
        city: 'London',
        country: 'GB',
        latitude: 51.4706,
        longitude: -0.4619),
    Airport(
        icao: 'EGKK',
        iata: 'LGW',
        name: 'London Gatwick Airport',
        city: 'London',
        country: 'GB',
        latitude: 51.1537,
        longitude: -0.1821),
    Airport(
        icao: 'EGSS',
        iata: 'STN',
        name: 'London Stansted Airport',
        city: 'London',
        country: 'GB',
        latitude: 51.8850,
        longitude: 0.2350),
    Airport(
        icao: 'EGGW',
        iata: 'LTN',
        name: 'London Luton Airport',
        city: 'London',
        country: 'GB',
        latitude: 51.8747,
        longitude: -0.3683),
    Airport(
        icao: 'EGCC',
        iata: 'MAN',
        name: 'Manchester Airport',
        city: 'Manchester',
        country: 'GB',
        latitude: 53.3537,
        longitude: -2.2750),
    Airport(
        icao: 'EGBB',
        iata: 'BHX',
        name: 'Birmingham Airport',
        city: 'Birmingham',
        country: 'GB',
        latitude: 52.4539,
        longitude: -1.7480),
    Airport(
        icao: 'EGPH',
        iata: 'EDI',
        name: 'Edinburgh Airport',
        city: 'Edinburgh',
        country: 'GB',
        latitude: 55.9500,
        longitude: -3.3725),
    Airport(
        icao: 'EGPF',
        iata: 'GLA',
        name: 'Glasgow Airport',
        city: 'Glasgow',
        country: 'GB',
        latitude: 55.8719,
        longitude: -4.4331),
    Airport(
        icao: 'EGGD',
        iata: 'BRS',
        name: 'Bristol Airport',
        city: 'Bristol',
        country: 'GB',
        latitude: 51.3827,
        longitude: -2.7191),
    Airport(
        icao: 'EGTE',
        iata: 'EXT',
        name: 'Exeter Airport',
        city: 'Exeter',
        country: 'GB',
        latitude: 50.7344,
        longitude: -3.4139),
    Airport(
        icao: 'EIDW',
        iata: 'DUB',
        name: 'Dublin Airport',
        city: 'Dublin',
        country: 'IE',
        latitude: 53.4213,
        longitude: -6.2701),
    Airport(
        icao: 'LFPG',
        iata: 'CDG',
        name: 'Paris Charles de Gaulle Airport',
        city: 'Paris',
        country: 'FR',
        latitude: 49.0097,
        longitude: 2.5479),
    Airport(
        icao: 'EHAM',
        iata: 'AMS',
        name: 'Amsterdam Airport Schiphol',
        city: 'Amsterdam',
        country: 'NL',
        latitude: 52.3105,
        longitude: 4.7683),
    Airport(
        icao: 'KJFK',
        iata: 'JFK',
        name: 'John F. Kennedy International Airport',
        city: 'New York',
        country: 'US',
        latitude: 40.639447,
        longitude: -73.779317),
    Airport(
        icao: 'KLGA',
        iata: 'LGA',
        name: 'LaGuardia Airport',
        city: 'New York',
        country: 'US',
        latitude: 40.777199,
        longitude: -73.872597),
    Airport(
        icao: 'KLAX',
        iata: 'LAX',
        name: 'Los Angeles International Airport',
        city: 'Los Angeles',
        country: 'US',
        latitude: 33.942501,
        longitude: -118.407997),
  ];

  @override
  Future<void> initialize() async {}

  @override
  List<Airport> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return airports;
    return airports.where((airport) {
      final values = [airport.iata, airport.icao, airport.name, airport.city];
      return values.whereType<String>().any((value) =>
          value.toLowerCase().contains(normalized) ||
          value
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), '')
              .contains(normalized.replaceAll(RegExp(r'\s+'), '')));
    }).toList(growable: false);
  }
}
