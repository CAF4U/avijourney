import 'dart:async';
import 'dart:convert';
import 'package:avijourney/app/weather/airport_weather_controller.dart';
import 'package:avijourney/data/weather/awc_weather_provider.dart';
import 'package:avijourney/data/weather/shared_preferences_weather_cache.dart';
import 'package:avijourney/data/weather/weather_mapping.dart';
import 'package:avijourney/domain/models/airport_weather.dart';
import 'package:avijourney/domain/providers/airport_weather_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime.utc(2026, 10, 31, 12);
Map<String, dynamic> metar() => {
      'icaoId': 'EGLL',
      'obsTime': now.millisecondsSinceEpoch ~/ 1000,
      'rawOb': 'METAR EGLL VRB02KT 9999 10/08 Q1032',
      'temp': 10,
      'dewp': 8,
      'wdir': 'VRB',
      'wspd': 2,
      'visib': '6+',
      'altim': 1032,
      'clouds': <Map<String, dynamic>>[],
      'fltCat': 'VFR'
    };
Map<String, dynamic> taf() => {
      'icaoId': 'EGLL',
      'rawTAF': 'TAF EGLL 3112/0112 TEMPO 2000 BR PROB30 FG',
      'issueTime': now.toIso8601String(),
      'validTimeFrom': now.millisecondsSinceEpoch ~/ 1000,
      'validTimeTo':
          now.add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
      'fcsts': [
        {
          'fcstChange': 'TEMPO',
          'probability': 30,
          'timeFrom': now.millisecondsSinceEpoch ~/ 1000,
          'timeTo':
              now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
          'visib': 1.24,
          'wxString': 'BR',
          'clouds': [
            {'cover': 'BKN', 'base': 200}
          ]
        }
      ]
    };

class FakeWeather implements AirportWeatherProvider {
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<AirportWeatherReport?> fetch(String station, WeatherKind kind) async {
    calls++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('offline');
    return reportFromAwc(kind == WeatherKind.metar ? metar() : taf(), kind);
  }
}

void main() {
  test(
      'AWC parses observations and conditional forecasts without converting units or losing raw reports',
      () {
    final m = reportFromAwc(metar(), WeatherKind.metar);
    expect(m.conditions.pressureHpa, 1032);
    expect(m.conditions.visibilityMiles, '6+');
    expect(m.conditions.windDirection, 'VRB');
    final t = reportFromAwc(taf(), WeatherKind.taf);
    expect(t.periods.single.change, 'TEMPO');
    expect(t.periods.single.probability, 30);
    expect(t.periods.single.conditions.clouds.single.baseFeet, 200);
    expect(t.periods.single.conditions.windSpeedKt, isNull);
    expect(t.raw, contains('PROB30'));
  });
  test(
      'AWC uses station queries/custom user agent, serial pacing, no-data and global rate-limit backoff',
      () async {
    var time = now;
    var calls = 0;
    final waits = <Duration>[];
    final provider = AwcWeatherProvider(
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters['ids'], 'EGLL');
          expect(request.headers['User-Agent'], contains('CAF4U'));
          if (calls == 1) return http.Response(jsonEncode([metar()]), 200);
          if (calls == 2) return http.Response('', 204);
          return http.Response('', 429, headers: {'retry-after': '120'});
        }),
        clock: () => time,
        wait: (d) async {
          waits.add(d);
          time = time.add(d);
        });
    expect(await provider.fetch('EGLL', WeatherKind.metar), isNotNull);
    expect(await provider.fetch('EGLL', WeatherKind.taf), isNull);
    expect(waits.single, const Duration(seconds: 1));
    await expectLater(
        provider.fetch('EGLL', WeatherKind.metar), throwsStateError);
    await expectLater(
        provider.fetch('KJFK', WeatherKind.metar), throwsStateError);
    expect(calls, 3);
  });
  test(
      'weather capability off means no requests; caches each report at independent TTLs and retains failures',
      () async {
    var time = now;
    final provider = FakeWeather();
    final c = AirportWeatherController(
        provider: provider,
        cache: MemoryWeatherCacheStore(),
        clock: () => time);
    addTearDown(c.dispose);
    await c.load('EGLL');
    expect(provider.calls, 0);
    c.setEnabled(true);
    await c.load('EGLL');
    expect(provider.calls, 2);
    await c.load('EGLL', force: true);
    expect(provider.calls, 2);
    time = time.add(const Duration(minutes: 11));
    await c.load('EGLL');
    expect(provider.calls, 3);
    time = time.add(const Duration(minutes: 31));
    provider.fail = true;
    await c.load('EGLL');
    final cached = c.reading('EGLL', WeatherKind.metar)!;
    expect(cached.report, isNotNull);
    expect(cached.fromCache, isTrue);
    expect(cached.problem, isNotNull);
    c.setEnabled(false);
    final before = provider.calls;
    await c.load('EGLL', force: true);
    expect(provider.calls, before);
  });
  test(
      'concurrent airport loads deduplicate; disabling during request discards result and prevents TAF request',
      () async {
    final provider = FakeWeather()..gate = Completer<void>();
    final c = AirportWeatherController(
        provider: provider, cache: MemoryWeatherCacheStore(), clock: () => now);
    addTearDown(c.dispose);
    c.setEnabled(true);
    final a = c.load('EGLL');
    final b = c.load('EGLL');
    await Future<void>.delayed(Duration.zero);
    expect(provider.calls, 1);
    c.setEnabled(false);
    provider.gate!.complete();
    await Future.wait([a, b]);
    expect(provider.calls, 1);
    expect(c.reading('EGLL', WeatherKind.metar), isNull);
  });
  test(
      'weather cache survives restart and malformed payload never replaces usable weather',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cache = SharedPreferencesWeatherCache();
    final reading = WeatherReading(
        report: reportFromAwc(taf(), WeatherKind.taf),
        fetchedAt: now,
        checkedAt: now);
    await cache.write('EGLL', WeatherKind.taf, reading);
    final restored =
        await SharedPreferencesWeatherCache().read('EGLL', WeatherKind.taf);
    expect(restored!.report!.raw, reading.report!.raw);
    expect(restored.report!.periods.single.probability, 30);
    final p = AwcWeatherProvider(
        client: MockClient((_) async => http.Response('{bad json', 200)),
        minimumSpacing: Duration.zero);
    await expectLater(
        p.fetch('EGLL', WeatherKind.metar), throwsFormatException);
    expect(weatherNumber('NaN'), isNull);
  });
}
