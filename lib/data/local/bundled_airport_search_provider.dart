import 'package:flutter/services.dart';

import '../../domain/models/airport.dart';
import '../../domain/providers/airport_search_provider.dart';
import 'static_airport_search_provider.dart';

class BundledAirportSearchProvider implements AirportSearchProvider {
  BundledAirportSearchProvider({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/data/global_airports.tsv';
  final AssetBundle _bundle;
  List<Airport> _airports = StaticAirportSearchProvider.airports;

  int get airportCount => _airports.length;

  @override
  Future<void> initialize() async {
    try {
      final text = await _bundle.loadString(assetPath);
      final parsed = text
          .split('\n')
          .skip(1)
          .map(_parseLine)
          .whereType<Airport>()
          .toList(growable: false);
      if (parsed.isNotEmpty) _airports = parsed;
    } catch (_) {
      // The embedded fallback keeps discovery available if an asset is damaged.
    }
  }

  Airport? _parseLine(String line) {
    final fields = line.trimRight().split('\t');
    if (fields.length != 8) return null;
    final latitude = double.tryParse(fields[6]);
    final longitude = double.tryParse(fields[7]);
    if (fields[0].isEmpty ||
        fields[1].isEmpty ||
        latitude == null ||
        longitude == null) {
      return null;
    }
    return Airport(
      icao: fields[0],
      iata: fields[1],
      name: fields[2],
      city: fields[3].isEmpty ? null : fields[3],
      country: fields[4].isEmpty ? null : fields[4],
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  List<Airport> search(String query) {
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return _airports.take(30).toList(growable: false);
    return _airports
        .where((airport) {
          final searchable = [
            airport.iata,
            airport.icao,
            airport.name,
            airport.city,
            airport.country,
          ].whereType<String>().join(' ').toLowerCase();
          return tokens.every(searchable.contains) ||
              searchable
                  .replaceAll(RegExp(r'\s+'), '')
                  .contains(query.toLowerCase().replaceAll(RegExp(r'\s+'), ''));
        })
        .take(100)
        .toList(growable: false);
  }
}
