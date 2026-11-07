import '../models/airline.dart';

abstract interface class AirlineSearchProvider {
  Future<void> initialize();
  List<Airline> get airlines;
  List<Airline> get operatorReferences;
  List<Airline> search(String query);
}
