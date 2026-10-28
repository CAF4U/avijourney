import '../models/airport.dart';

abstract interface class AirportSearchProvider {
  Future<void> initialize();
  List<Airport> search(String query);
}
