import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../core/errors/provider_exception.dart';
import '../../domain/models/aircraft_state.dart';
import '../../domain/providers/aircraft_position_provider.dart';

class GeographicBounds {
  const GeographicBounds({
    required this.minimumLatitude,
    required this.minimumLongitude,
    required this.maximumLatitude,
    required this.maximumLongitude,
  });

  final double minimumLatitude;
  final double minimumLongitude;
  final double maximumLatitude;
  final double maximumLongitude;
}

class OpenSkyAircraftPositionProvider implements AircraftPositionProvider {
  OpenSkyAircraftPositionProvider({
    required http.Client client,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client,
        _endpoint =
            endpoint ?? Uri.parse('https://opensky-network.org/api/states/all');

  final http.Client _client;
  final Uri _endpoint;
  final Duration timeout;

  static GeographicBounds boundsFor({
    required double centerLatitude,
    required double centerLongitude,
    required double radiusNauticalMiles,
  }) {
    final latitudeDelta = radiusNauticalMiles / 60;
    final longitudeScale =
        math.max(0.01, math.cos(centerLatitude * math.pi / 180).abs());
    final longitudeDelta = radiusNauticalMiles / (60 * longitudeScale);
    return GeographicBounds(
      minimumLatitude: math.max(-90, centerLatitude - latitudeDelta),
      minimumLongitude: math.max(-180, centerLongitude - longitudeDelta),
      maximumLatitude: math.min(90, centerLatitude + latitudeDelta),
      maximumLongitude: math.min(180, centerLongitude + longitudeDelta),
    );
  }

  Uri requestUri({
    required double centerLatitude,
    required double centerLongitude,
    required double radiusNauticalMiles,
  }) {
    final bounds = boundsFor(
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      radiusNauticalMiles: radiusNauticalMiles,
    );
    return _endpoint.replace(queryParameters: {
      'lamin': bounds.minimumLatitude.toStringAsFixed(6),
      'lomin': bounds.minimumLongitude.toStringAsFixed(6),
      'lamax': bounds.maximumLatitude.toStringAsFixed(6),
      'lomax': bounds.maximumLongitude.toStringAsFixed(6),
    });
  }

  @override
  Future<List<AircraftState>> fetchAircraft({
    required double centerLatitude,
    required double centerLongitude,
    required double radiusNauticalMiles,
  }) async {
    final uri = requestUri(
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      radiusNauticalMiles: radiusNauticalMiles,
    );
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode == 429) {
        throw const ProviderException(
            ProviderErrorType.rateLimited, 'OpenSky rate limit reached');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ProviderException(
            ProviderErrorType.unauthorized, 'OpenSky request unauthorized');
      }
      if (response.statusCode >= 500) {
        throw const ProviderException(ProviderErrorType.serviceUnavailable,
            'OpenSky is temporarily unavailable');
      }
      if (response.statusCode != 200) {
        throw ProviderException(ProviderErrorType.unknown,
            'OpenSky returned HTTP ${response.statusCode}');
      }
      return parseResponse(response.body);
    } on ProviderException {
      rethrow;
    } on TimeoutException {
      throw const ProviderException(
          ProviderErrorType.timeout, 'OpenSky request timed out');
    } on http.ClientException {
      throw const ProviderException(
          ProviderErrorType.networkUnavailable, 'OpenSky network unavailable');
    } on FormatException {
      throw const ProviderException(
          ProviderErrorType.malformedResponse, 'Malformed OpenSky response');
    } catch (error) {
      throw ProviderException(
          ProviderErrorType.unknown, 'OpenSky request failed: $error');
    }
  }

  static List<AircraftState> parseResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected an OpenSky response object');
    }
    final responseTime = _asInt(decoded['time']);
    final rows = decoded['states'];
    if (rows == null) return const [];
    if (rows is! List) throw const FormatException('Invalid states collection');
    final aircraft = <AircraftState>[];
    for (final value in rows) {
      try {
        if (value is! List || value.length < 17) continue;
        final icao24 = _asString(value[0]).toLowerCase();
        final longitude = _asDouble(value[5]);
        final latitude = _asDouble(value[6]);
        if (icao24.isEmpty || latitude == null || longitude == null) continue;
        final observedSeconds = _asInt(value[4]) ?? responseTime;
        aircraft.add(AircraftState(
          icao24: icao24,
          callsign: _asString(value[1]).trim(),
          latitude: latitude,
          longitude: longitude,
          altitudeFeet:
              (_asDouble(value[7]) ?? _asDouble(value[13]) ?? 0) * 3.28084,
          groundSpeedKnots: (_asDouble(value[9]) ?? 0) * 1.94384,
          trackDegrees: _asDouble(value[10]) ?? 0,
          verticalRateFeetPerMinute: (_asDouble(value[11]) ?? 0) * 196.8504,
          squawk: _nullableString(value[14]),
          onGround: value[8] == true,
          hasGroundState: value[8] is bool,
          hasSpeed: _asDouble(value[9]) != null,
          hasPositionTimestamp: _asInt(value[3]) != null,
          positionObservedAt: _asInt(value[3]) == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(_asInt(value[3])! * 1000,
                  isUtc: true),
          observedAt: DateTime.fromMillisecondsSinceEpoch(
            (observedSeconds ?? 0) * 1000,
            isUtc: true,
          ),
        ));
      } catch (_) {
        // A malformed row is ignored without discarding other valid aircraft.
      }
    }
    return aircraft;
  }

  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
  static int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');
  static String _asString(Object? value) => value is String ? value : '';
  static String? _nullableString(Object? value) {
    final text = _asString(value).trim();
    return text.isEmpty ? null : text;
  }
}
