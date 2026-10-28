import 'package:flutter/services.dart';

import '../../domain/models/airline.dart';
import '../../domain/providers/airline_search_provider.dart';
import 'static_airline_catalog.dart';

class BundledAirlineSearchProvider implements AirlineSearchProvider {
  BundledAirlineSearchProvider({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/data/global_airlines.tsv';
  final AssetBundle _bundle;
  List<Airline> _airlines = StaticAirlineCatalog.entries;

  @override
  List<Airline> get airlines => _airlines;

  @override
  Future<void> initialize() async {
    try {
      final text = await _bundle.loadString(assetPath);
      final parsed = text
          .split('\n')
          .skip(1)
          .map(_parseLine)
          .whereType<Airline>()
          .toList(growable: false);
      if (parsed.isNotEmpty) _airlines = parsed;
    } catch (_) {
      // The curated fallback keeps discovery available if an asset is damaged.
    }
  }

  Airline? _parseLine(String line) {
    final fields = line.trimRight().split('\t');
    if (fields.length != 4 || fields[0].isEmpty) return null;
    final iata = fields[1].isEmpty ? null : fields[1];
    final icao = fields[2].isEmpty ? null : fields[2];
    if (iata == null && icao == null) return null;
    return Airline(name: fields[0], iataCode: iata, icaoCode: icao);
  }

  @override
  List<Airline> search(String query) {
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return _airlines;
    return _airlines
        .where((airline) {
          final searchable = [airline.name, airline.iataCode, airline.icaoCode]
              .whereType<String>()
              .join(' ')
              .toLowerCase();
          return tokens.every(searchable.contains);
        })
        .take(100)
        .toList(growable: false);
  }
}
