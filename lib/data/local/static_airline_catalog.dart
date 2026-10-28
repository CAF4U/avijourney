import '../../domain/models/airline.dart';
import '../../domain/providers/airline_search_provider.dart';

class StaticAirlineCatalog implements AirlineSearchProvider {
  const StaticAirlineCatalog();

  static const entries = <Airline>[
    Airline(name: 'British Airways', iataCode: 'BA', icaoCode: 'BAW'),
    Airline(name: 'easyJet UK', iataCode: 'U2', icaoCode: 'EZY'),
    Airline(name: 'Emirates', iataCode: 'EK', icaoCode: 'UAE'),
    Airline(name: 'Virgin Atlantic', iataCode: 'VS', icaoCode: 'VIR'),
    Airline(name: 'Ryanair', iataCode: 'FR', icaoCode: 'RYR'),
    Airline(name: 'KLM', iataCode: 'KL', icaoCode: 'KLM'),
    Airline(name: 'Lufthansa', iataCode: 'LH', icaoCode: 'DLH'),
    Airline(name: 'Air France', iataCode: 'AF', icaoCode: 'AFR'),
    Airline(name: 'American Airlines', iataCode: 'AA', icaoCode: 'AAL'),
    Airline(name: 'United Airlines', iataCode: 'UA', icaoCode: 'UAL'),
    Airline(name: 'Air Canada', iataCode: 'AC', icaoCode: 'ACA'),
    Airline(name: 'Delta Air Lines', iataCode: 'DL', icaoCode: 'DAL'),
    Airline(name: 'Southwest Airlines', iataCode: 'WN', icaoCode: 'SWA'),
    Airline(name: 'Alaska Airlines', iataCode: 'AS', icaoCode: 'ASA'),
    Airline(name: 'Aer Lingus', iataCode: 'EI', icaoCode: 'EIN'),
    Airline(name: 'Iberia', iataCode: 'IB', icaoCode: 'IBE'),
    Airline(name: 'TAP Air Portugal', iataCode: 'TP', icaoCode: 'TAP'),
    Airline(name: 'SAS', iataCode: 'SK', icaoCode: 'SAS'),
    Airline(name: 'Finnair', iataCode: 'AY', icaoCode: 'FIN'),
    Airline(name: 'Turkish Airlines', iataCode: 'TK', icaoCode: 'THY'),
    Airline(name: 'Qatar Airways', iataCode: 'QR', icaoCode: 'QTR'),
    Airline(name: 'Etihad Airways', iataCode: 'EY', icaoCode: 'ETD'),
    Airline(name: 'Saudia', iataCode: 'SV', icaoCode: 'SVA'),
    Airline(name: 'El Al', iataCode: 'LY', icaoCode: 'ELY'),
    Airline(name: 'Ethiopian Airlines', iataCode: 'ET', icaoCode: 'ETH'),
    Airline(name: 'Kenya Airways', iataCode: 'KQ', icaoCode: 'KQA'),
    Airline(name: 'South African Airways', iataCode: 'SA', icaoCode: 'SAA'),
    Airline(name: 'Royal Air Maroc', iataCode: 'AT', icaoCode: 'RAM'),
    Airline(name: 'EgyptAir', iataCode: 'MS', icaoCode: 'MSR'),
    Airline(name: 'Air India', iataCode: 'AI', icaoCode: 'AIC'),
    Airline(name: 'IndiGo', iataCode: '6E', icaoCode: 'IGO'),
    Airline(name: 'Singapore Airlines', iataCode: 'SQ', icaoCode: 'SIA'),
    Airline(name: 'Cathay Pacific', iataCode: 'CX', icaoCode: 'CPA'),
    Airline(name: 'Japan Airlines', iataCode: 'JL', icaoCode: 'JAL'),
    Airline(name: 'All Nippon Airways', iataCode: 'NH', icaoCode: 'ANA'),
    Airline(name: 'Korean Air', iataCode: 'KE', icaoCode: 'KAL'),
    Airline(name: 'China Airlines', iataCode: 'CI', icaoCode: 'CAL'),
    Airline(name: 'Air China', iataCode: 'CA', icaoCode: 'CCA'),
    Airline(name: 'China Eastern', iataCode: 'MU', icaoCode: 'CES'),
    Airline(name: 'China Southern', iataCode: 'CZ', icaoCode: 'CSN'),
    Airline(name: 'Qantas', iataCode: 'QF', icaoCode: 'QFA'),
    Airline(name: 'Air New Zealand', iataCode: 'NZ', icaoCode: 'ANZ'),
    Airline(name: 'LATAM Airlines', iataCode: 'LA', icaoCode: 'LAN'),
    Airline(name: 'Avianca', iataCode: 'AV', icaoCode: 'AVA'),
    Airline(name: 'Aeromexico', iataCode: 'AM', icaoCode: 'AMX'),
  ];

  @override
  List<Airline> get airlines => entries;

  @override
  Future<void> initialize() async {}

  @override
  List<Airline> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return entries;
    return entries
        .where((airline) => [
              airline.name,
              airline.iataCode,
              airline.icaoCode,
            ].whereType<String>().any(
                  (value) => value.toLowerCase().contains(normalized),
                ))
        .toList(growable: false);
  }
}
