import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/airport_weather.dart';
import '../../domain/providers/airport_weather_provider.dart';
import 'weather_mapping.dart';

class AwcWeatherProvider implements AirportWeatherProvider {
  AwcWeatherProvider(
      {required this.client,
      DateTime Function()? clock,
      Future<void> Function(Duration)? wait,
      this.minimumSpacing = const Duration(seconds: 1)})
      : clock = clock ?? DateTime.now,
        wait = wait ?? Future<void>.delayed;
  final http.Client client;
  final DateTime Function() clock;
  final Future<void> Function(Duration) wait;
  final Duration minimumSpacing;
  Future<void> _queue = Future.value();
  DateTime? _lastRequest, _blockedUntil;
  @override
  Future<AirportWeatherReport?> fetch(String station, WeatherKind kind) {
    final result = Completer<AirportWeatherReport?>();
    _queue = _queue.then((_) async {
      try {
        result.complete(await _fetch(station, kind));
      } catch (e, stack) {
        result.completeError(e, stack);
      }
    });
    return result.future;
  }

  Future<AirportWeatherReport?> _fetch(String station, WeatherKind kind) async {
    if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(station))
      throw const FormatException(
          'Weather requires a four-character station identifier');
    if (_blockedUntil != null && clock().isBefore(_blockedUntil!))
      throw StateError('Weather provider rate-limited; retry later');
    if (_lastRequest != null) {
      final remaining = minimumSpacing - clock().difference(_lastRequest!);
      if (remaining > Duration.zero) await wait(remaining);
    }
    _lastRequest = clock();
    final response = await client.get(
        Uri.https('aviationweather.gov', '/api/data/${kind.name}',
            {'ids': station, 'format': 'json'}),
        headers: {
          'User-Agent': 'CAF4U-Aircraft-Companion/0.4.0 (airport weather)',
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 15));
    if (response.statusCode == 429) {
      final seconds =
          int.tryParse(response.headers['retry-after'] ?? '') ?? 300;
      _blockedUntil =
          clock().add(Duration(seconds: seconds < 60 ? 60 : seconds));
      throw StateError('Weather provider rate-limited; retry later');
    }
    if (response.statusCode == 204) return null;
    if (response.statusCode != 200)
      throw StateError('Weather request failed (HTTP ${response.statusCode})');
    final data = jsonDecode(response.body);
    if (data is! List)
      throw const FormatException('Malformed weather response');
    final reports = data
        .whereType<Map<dynamic, dynamic>>()
        .where((r) => r['icaoId']?.toString().toUpperCase() == station)
        .map((r) => reportFromAwc(Map<String, dynamic>.from(r), kind))
        .toList();
    reports.sort((a, b) =>
        (b.issuedAt ?? DateTime(1970)).compareTo(a.issuedAt ?? DateTime(1970)));
    return reports.firstOrNull;
  }
}
