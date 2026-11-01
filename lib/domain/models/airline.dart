class Airline {
  const Airline(
      {required this.name,
      this.iataCode,
      this.icaoCode,
      this.country,
      this.aliases = const [],
      this.source,
      this.sourceUrls = const [],
      this.referenceDate});

  final String name;
  final List<String> aliases;
  final String? source;
  final List<String> sourceUrls;
  final String? referenceDate;
  final String? country;
  final String? iataCode;
  final String? icaoCode;

  bool matchesOperatorName(String? value) {
    if (value == null) return false;
    String normalize(String text) =>
        text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final key = normalize(value);
    if (key.isEmpty) return false;
    return normalize(name) == key ||
        aliases.any((alias) =>
            !RegExp(r'^[A-Z0-9]{2,3}$').hasMatch(alias.toUpperCase()) &&
            normalize(alias) == key);
  }

  String get identifier => icaoCode ?? iataCode ?? name;
}
