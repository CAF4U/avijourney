import 'dart:convert';
import 'package:flutter/services.dart';
import 'verified_operator_references.dart';

import '../../domain/models/airline.dart';
import '../../domain/providers/airline_search_provider.dart';
import 'static_airline_catalog.dart';

class BundledAirlineSearchProvider implements AirlineSearchProvider {
  BundledAirlineSearchProvider({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/data/global_airlines.tsv';
  final AssetBundle _bundle;
  List<Airline> _airlines = StaticAirlineCatalog.entries;
  List<Airline> _references = StaticAirlineCatalog.entries;

  @override
  List<Airline> get operatorReferences => _references;

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
      if (parsed.isNotEmpty) {
        final verifiedCodes =
            verifiedOperatorReferences.map((a) => a.icaoCode).toSet();
        _airlines = [
          ...verifiedOperatorReferences,
          ...parsed.where((a) => !verifiedCodes.contains(a.icaoCode))
        ];
      }
    } catch (_) {
      // The curated fallback keeps discovery available if an asset is damaged.
    }
    _references = _airlines;
    try {
      final raw = jsonDecode(
              await _bundle.loadString('assets/data/operator_references.json'))
          as List<dynamic>;
      final supplemental = <Airline>[];
      for (final value in raw) {
        if (value is! Map<String, dynamic>) continue;
        final name = value['name'];
        final icao = value['icao'];
        if (name is! String ||
            name.isEmpty ||
            icao is! String ||
            !RegExp(r'^[A-Z]{3}$').hasMatch(icao)) continue;
        final aliases = value['aliases'];
        final urls = value['urls'];
        supplemental.add(Airline(
            name: name,
            icaoCode: icao,
            iataCode: value['iata'] is String ? value['iata'] as String : null,
            country:
                value['country'] is String ? value['country'] as String : null,
            aliases: aliases is List<dynamic>
                ? aliases.whereType<String>().toList()
                : const [],
            source:
                value['source'] is String ? value['source'] as String : null,
            sourceUrls: urls is List<dynamic>
                ? urls.whereType<String>().toList()
                : const [],
            referenceDate:
                value['date'] is String ? value['date'] as String : null));
      }
      _references = [..._airlines, ...supplemental];
    } catch (_) {
      // Operator enrichment is optional; never discard the usable catalogue.
    }
  }

  Airline? _parseLine(String line) {
    final fields = line.trimRight().split('\t');
    if (fields.length != 4 || fields[0].isEmpty) return null;
    final iata = fields[1].isEmpty ? null : fields[1];
    final icao = fields[2].isEmpty ? null : fields[2];
    if (iata == null && icao == null) return null;
    return Airline(
        source: 'OpenFlights (ODbL; reference status unverified)',
        sourceUrls: const ['https://openflights.org/data.php'],
        referenceDate: '2026-10-28',
        name: fields[0],
        iataCode: iata,
        icaoCode: icao,
        country: fields[3].isEmpty ? null : fields[3]);
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
