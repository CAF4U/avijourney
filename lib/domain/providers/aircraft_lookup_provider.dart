import '../models/aircraft_state.dart';

/// One known airframe, independent of scan geography. Never a global snapshot.
abstract interface class AircraftLookupProvider {
  Future<AircraftState?> fetchByAddress(String icao24);
}
