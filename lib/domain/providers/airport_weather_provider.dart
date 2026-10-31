import '../models/airport_weather.dart';

abstract interface class AirportWeatherProvider {
  Future<AirportWeatherReport?> fetch(String station, WeatherKind kind);
}

class UnavailableWeatherProvider implements AirportWeatherProvider {
  const UnavailableWeatherProvider();
  @override
  Future<AirportWeatherReport?> fetch(String station, WeatherKind kind) async =>
      null;
}

abstract interface class WeatherCacheStore {
  Future<WeatherReading?> read(String station, WeatherKind kind);
  Future<void> write(String station, WeatherKind kind, WeatherReading reading);
}

class MemoryWeatherCacheStore implements WeatherCacheStore {
  final _values = <String, WeatherReading>{};
  @override
  Future<WeatherReading?> read(String station, WeatherKind kind) async =>
      _values['$station-${kind.name}'];
  @override
  Future<void> write(
      String station, WeatherKind kind, WeatherReading reading) async {
    _values['$station-${kind.name}'] = reading;
  }
}
