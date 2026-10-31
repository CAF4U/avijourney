class Airport {
  const Airport({
    required this.icao,
    this.iata,
    required this.name,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.type,
  });

  final String icao;
  final String? iata;
  final String name;
  final String? type;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;

  String get displayCode => iata?.isNotEmpty == true ? iata! : icao;
}
