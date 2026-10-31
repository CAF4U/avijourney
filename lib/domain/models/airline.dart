class Airline {
  const Airline(
      {required this.name, this.iataCode, this.icaoCode, this.country});

  final String name;
  final String? country;
  final String? iataCode;
  final String? icaoCode;

  String get identifier => icaoCode ?? iataCode ?? name;
}
