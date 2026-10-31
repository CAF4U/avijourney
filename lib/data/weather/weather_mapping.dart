import '../../domain/models/airport_weather.dart';

double? weatherNumber(dynamic value) {
  final n = value is num ? value.toDouble() : double.tryParse('$value');
  return n != null && n.isFinite ? n : null;
}

DateTime? weatherTime(dynamic value) => value is num
    ? DateTime.fromMillisecondsSinceEpoch((value * 1000).round(), isUtc: true)
    : value is String
        ? DateTime.tryParse(value)?.toUtc()
        : null;
WeatherConditions conditionsFromAwc(Map<String, dynamic> row) =>
    WeatherConditions(
        temperatureC: weatherNumber(row['temp']),
        dewpointC: weatherNumber(row['dewp']),
        windDirection: row['wdir']?.toString(),
        windSpeedKt: weatherNumber(row['wspd']),
        windGustKt: weatherNumber(row['wgst']),
        visibilityMiles: row['visib']?.toString(),
        pressureHpa: weatherNumber(row['altim']),
        weatherCodes: row['wxString'] as String?,
        flightCategory: row['fltCat'] as String?,
        clouds: (row['clouds'] as List<dynamic>? ?? [])
            .whereType<Map<dynamic, dynamic>>()
            .map((c) => WeatherCloud(
                c['cover']?.toString() ?? 'Unknown', weatherNumber(c['base'])))
            .toList());
AirportWeatherReport reportFromAwc(Map<String, dynamic> row, WeatherKind kind) {
  final station = row['icaoId']?.toString().toUpperCase();
  final raw = row[kind == WeatherKind.metar ? 'rawOb' : 'rawTAF']?.toString();
  if (station == null || raw == null || raw.trim().isEmpty)
    throw const FormatException('Incomplete weather report');
  return AirportWeatherReport(
      station: station,
      kind: kind,
      raw: raw,
      issuedAt:
          weatherTime(row[kind == WeatherKind.metar ? 'obsTime' : 'issueTime']),
      validFrom: weatherTime(row['validTimeFrom']),
      validTo: weatherTime(row['validTimeTo']),
      conditions: conditionsFromAwc(row),
      periods: (row['fcsts'] as List<dynamic>? ?? [])
          .whereType<Map<dynamic, dynamic>>()
          .map((p) => ForecastPeriod(
              from: weatherTime(p['timeFrom']),
              to: weatherTime(p['timeTo']),
              becomingAt: weatherTime(p['timeBec']),
              change: p['fcstChange'] as String?,
              probability: weatherNumber(p['probability'])?.round(),
              conditions: conditionsFromAwc(Map<String, dynamic>.from(p))))
          .toList());
}

// Local cache schema, deliberately distinct from external provider JSON.
Map<String, dynamic> _conditions(WeatherConditions c) => {
      'temperatureC': c.temperatureC,
      'dewpointC': c.dewpointC,
      'windDirection': c.windDirection,
      'windSpeedKt': c.windSpeedKt,
      'windGustKt': c.windGustKt,
      'visibilityMiles': c.visibilityMiles,
      'pressureHpa': c.pressureHpa,
      'weatherCodes': c.weatherCodes,
      'flightCategory': c.flightCategory,
      'clouds': c.clouds
          .map((v) => {'cover': v.cover, 'baseFeet': v.baseFeet})
          .toList()
    };
WeatherConditions _cachedConditions(Map<String, dynamic> c) =>
    WeatherConditions(
        temperatureC: weatherNumber(c['temperatureC']),
        dewpointC: weatherNumber(c['dewpointC']),
        windDirection: c['windDirection'] as String?,
        windSpeedKt: weatherNumber(c['windSpeedKt']),
        windGustKt: weatherNumber(c['windGustKt']),
        visibilityMiles: c['visibilityMiles'] as String?,
        pressureHpa: weatherNumber(c['pressureHpa']),
        weatherCodes: c['weatherCodes'] as String?,
        flightCategory: c['flightCategory'] as String?,
        clouds: (c['clouds'] as List<dynamic>)
            .map((v) => WeatherCloud(
                v['cover'] as String, weatherNumber(v['baseFeet'])))
            .toList());
Map<String, dynamic> weatherCacheJson(WeatherReading reading) {
  final r = reading.report!;
  return {
    'station': r.station,
    'kind': r.kind.name,
    'raw': r.raw,
    'issuedAt': r.issuedAt?.toIso8601String(),
    'validFrom': r.validFrom?.toIso8601String(),
    'validTo': r.validTo?.toIso8601String(),
    'conditions': _conditions(r.conditions),
    'periods': r.periods
        .map((p) => {
              'from': p.from?.toIso8601String(),
              'to': p.to?.toIso8601String(),
              'becomingAt': p.becomingAt?.toIso8601String(),
              'change': p.change,
              'probability': p.probability,
              'conditions': _conditions(p.conditions)
            })
        .toList(),
    'fetchedAt': reading.fetchedAt?.toIso8601String(),
    'checkedAt': reading.checkedAt.toIso8601String()
  };
}

WeatherReading weatherCacheFromJson(Map<String, dynamic> v) => WeatherReading(
    report: AirportWeatherReport(
        station: v['station'] as String,
        kind: WeatherKind.values.byName(v['kind'] as String),
        raw: v['raw'] as String,
        issuedAt: weatherTime(v['issuedAt']),
        validFrom: weatherTime(v['validFrom']),
        validTo: weatherTime(v['validTo']),
        conditions: _cachedConditions(Map<String, dynamic>.from(
            v['conditions'] as Map<dynamic, dynamic>)),
        periods: (v['periods'] as List<dynamic>)
            .map((p) => ForecastPeriod(
                from: weatherTime(p['from']),
                to: weatherTime(p['to']),
                becomingAt: weatherTime(p['becomingAt']),
                change: p['change'] as String?,
                probability: p['probability'] as int?,
                conditions: _cachedConditions(Map<String, dynamic>.from(
                    p['conditions'] as Map<dynamic, dynamic>))))
            .toList()),
    fetchedAt: weatherTime(v['fetchedAt']),
    checkedAt: weatherTime(v['checkedAt'])!,
    fromCache: true);
