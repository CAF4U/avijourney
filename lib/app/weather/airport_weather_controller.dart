import 'package:flutter/foundation.dart';
import '../../domain/models/airport_weather.dart';
import '../../domain/providers/airport_weather_provider.dart';

class AirportWeatherController extends ChangeNotifier {
  AirportWeatherController(
      {required this.provider, required this.cache, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final AirportWeatherProvider provider;
  final WeatherCacheStore cache;
  final DateTime Function() clock;
  bool enabled = false, foreground = true, _disposed = false;
  int _generation = 0;
  final _readings = <String, WeatherReading>{};
  final _loading = <String>{};
  final _inflight = <String, Future<void>>{};
  WeatherReading? reading(String station, WeatherKind kind) =>
      _readings['$station-${kind.name}'];
  bool loading(String station) => _loading.contains(station);
  void setEnabled(bool value) {
    if (value == enabled) return;
    enabled = value;
    _generation++;
    _loading.clear();
    _notify();
  }

  void setForeground(bool value) {
    foreground = value;
    if (!value) {
      _generation++;
      _loading.clear();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load(String code, {bool force = false}) {
    final station = code.toUpperCase();
    if (!enabled || !foreground || _disposed) return Future.value();
    return _inflight[station] ??=
        _load(station, force).whenComplete(() => _inflight.remove(station));
  }

  Future<void> _load(String station, bool force) async {
    final generation = _generation;
    _loading.add(station);
    _notify();
    try {
      for (final kind in WeatherKind.values) {
        if (!enabled || !foreground || generation != _generation || _disposed)
          break;
        final key = '$station-${kind.name}';
        final previous = _readings[key] ?? await cache.read(station, kind);
        if (previous != null) _readings[key] = previous;
        if (!enabled || !foreground || generation != _generation || _disposed)
          break;
        final ttl = kind == WeatherKind.metar
            ? const Duration(minutes: 10)
            : const Duration(minutes: 30);
        if (previous != null &&
            clock().difference(previous.checkedAt) <
                (force
                    ? const Duration(seconds: 60)
                    : previous.problem != null || previous.noReport
                        ? const Duration(minutes: 2)
                        : ttl)) {
          _readings[key] = WeatherReading(
              report: previous.report,
              fetchedAt: previous.fetchedAt,
              checkedAt: previous.checkedAt,
              fromCache: previous.report != null,
              problem: previous.problem,
              noReport: previous.noReport);
          continue;
        }
        try {
          final report = await provider.fetch(station, kind);
          if (generation != _generation || !enabled || !foreground || _disposed)
            break;
          final now = clock();
          final value = WeatherReading(
              report: report ?? previous?.report,
              fetchedAt: report == null ? previous?.fetchedAt : now,
              checkedAt: now,
              fromCache: report == null && previous?.report != null,
              noReport: report == null);
          _readings[key] = value;
          if (report != null) await cache.write(station, kind, value);
        } catch (_) {
          if (generation != _generation || _disposed) break;
          _readings[key] = WeatherReading(
              report: previous?.report,
              fetchedAt: previous?.fetchedAt,
              checkedAt: clock(),
              fromCache: previous?.report != null,
              problem:
                  'Weather unavailable or rate limited. Last usable report retained when available.');
        }
        _notify();
      }
    } finally {
      _loading.remove(station);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
