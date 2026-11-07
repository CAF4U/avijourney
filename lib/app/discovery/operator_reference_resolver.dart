import '../../domain/models/airline.dart';

String normalizeOperatorName(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Exact normalized names and recorded aliases only. No substring, callsign
/// transformation or IATA-only identity matching.
Airline resolveOperatorReference(String name, Iterable<Airline> references) {
  final key = normalizeOperatorName(name);
  if (key.isEmpty) return Airline(name: name);
  final matches = references.where((a) => a.matchesOperatorName(name)).toList();
  if (matches.isEmpty) return Airline(name: name);
  Set<String> values(String? Function(Airline) field) =>
      matches.map(field).whereType<String>().where((s) => s.isNotEmpty).toSet();
  final icaos = values((a) => a.icaoCode);
  final iatas = values((a) => a.iataCode);
  final countries = values((a) => a.country);
  if (icaos.length > 1 || iatas.length > 1 || countries.length > 1) {
    return Airline(
        name: name,
        source:
            'Ambiguous operator reference matches; identity left unresolved');
  }
  return Airline(
      name: matches.first.name,
      icaoCode: icaos.singleOrNull,
      iataCode: iatas.singleOrNull,
      country: countries.singleOrNull,
      aliases: {
        name,
        for (final a in matches) ...[a.name, ...a.aliases]
      }.toList(),
      source: values((a) => a.source).join('; '),
      sourceUrls: {for (final a in matches) ...a.sourceUrls}.toList(),
      referenceDate: values((a) => a.referenceDate).join(', '));
}
