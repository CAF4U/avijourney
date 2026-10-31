import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/airport_weather.dart';
import '../../domain/providers/airport_weather_provider.dart';
import 'weather_mapping.dart';

class SharedPreferencesWeatherCache implements WeatherCacheStore {
  final _memory = <String, WeatherReading>{};
  Future<void> _writes = Future<void>.value();
  @override
  Future<WeatherReading?> read(String station, WeatherKind kind) async {
    final key = '$station-${kind.name}';
    if (_memory.containsKey(key)) return _memory[key];
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = jsonDecode(prefs.getString('airport_weather_v1') ?? '{}')
          as Map<String, dynamic>;
      final raw = all[key];
      if (raw == null) return null;
      return _memory[key] = weatherCacheFromJson(
          Map<String, dynamic>.from(raw as Map<dynamic, dynamic>));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String station, WeatherKind kind, WeatherReading reading) {
    _writes = _writes.then((_) => _write(station, kind, reading));
    return _writes;
  }

  Future<void> _write(
      String station, WeatherKind kind, WeatherReading reading) async {
    if (reading.report == null) return;
    _memory['$station-${kind.name}'] = reading;
    while (_memory.length > 60) {
      _memory.remove(_memory.keys.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> all;
      try {
        all = jsonDecode(prefs.getString('airport_weather_v1') ?? '{}')
            as Map<String, dynamic>;
      } catch (_) {
        all = {};
      }
      all.remove('$station-${kind.name}');
      all['$station-${kind.name}'] = weatherCacheJson(reading);
      while (all.length > 60) {
        all.remove(all.keys.first);
      }
      await prefs.setString('airport_weather_v1', jsonEncode(all));
    } catch (_) {/* Read-only or failed storage must not hide weather. */}
  }
}
