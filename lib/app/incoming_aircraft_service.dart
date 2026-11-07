import 'dart:math' as math;
import '../domain/models/airport.dart';
import '../domain/models/tracked_aircraft.dart';
import '../domain/models/aircraft_identity.dart';
import '../domain/models/flight_route.dart';
import '../domain/models/incoming_aircraft.dart';
import '../domain/providers/aircraft_lookup_provider.dart';
import '../domain/providers/aircraft_enrichment_provider.dart';

class IncomingAircraftService {
  IncomingAircraftService(
      {required AircraftLookupProvider positions,
      required AircraftEnrichmentProvider enrichment,
      DateTime Function()? clock,
      this.positionSource = 'OpenSky'})
      : _positions = positions,
        _enrichment = enrichment,
        _clock = clock ?? DateTime.now;
  final AircraftLookupProvider _positions;
  final AircraftEnrichmentProvider _enrichment;
  final DateTime Function() _clock;
  final String positionSource;
  final Map<String, ({DateTime at, TrackedAircraft? aircraft, bool failed})>
      _cache = {};
  final Map<String, Future<({TrackedAircraft? aircraft, bool failed})>>
      _pending = {};

  final Map<String, TrackedAircraft> _lastUsable = {};

  Future<({TrackedAircraft? aircraft, bool failed})> _load(
      String address) async {
    try {
      final state = await _positions.fetchByAddress(address);
      if (state == null) return (aircraft: null, failed: false);
      // Never borrow an outbound record's callsign, route or commercial number.
      AircraftIdentity? identity;
      FlightRoute? route;
      try {
        identity = await _enrichment.resolveAircraft(address);
      } catch (_) {}
      if (state.callsign.isNotEmpty) {
        try {
          route = await _enrichment.resolveRoute(state.callsign);
        } catch (_) {}
      }
      return (
        aircraft:
            TrackedAircraft(state: state, identity: identity, route: route),
        failed: false
      );
    } catch (_) {
      return (aircraft: null, failed: true);
    }
  }

  Future<IncomingAircraft> find(
      {required String address,
      required Airport airport,
      String? expectedRegistration,
      String? outboundCallsign}) async {
    final key = address.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{6}$').hasMatch(key))
      throw ArgumentError('A six-character ICAO24 address is required');
    final cached = _cache[key];
    late ({TrackedAircraft? aircraft, bool failed}) result;
    if (cached != null &&
        _clock().difference(cached.at) < const Duration(seconds: 30)) {
      result = (aircraft: cached.aircraft, failed: cached.failed);
    } else {
      final request = _pending.putIfAbsent(key, () => _load(key));
      try {
        result = await request;
        if (result.failed) result = (aircraft: _lastUsable[key], failed: true);
        if (!result.failed && result.aircraft != null)
          _lastUsable[key] = result.aircraft!;
        _cache[key] =
            (at: _clock(), aircraft: result.aircraft, failed: result.failed);
      } finally {
        if (identical(_pending[key], request)) _pending.remove(key);
      }
    }
    final aircraft = result.aircraft;
    final state = result.failed
        ? IncomingState.lookupFailed
        : aircraft == null
            ? IncomingState.notObserved
            : assess(aircraft, airport, key, _clock(),
                expectedRegistration: expectedRegistration,
                outboundCallsign: outboundCallsign);
    return IncomingAircraft(
        airport: airport,
        address: key,
        state: state,
        checkedAt: _cache[key]!.at,
        outboundCallsign: outboundCallsign,
        aircraft: aircraft,
        evidence:
            '$positionSource targeted ICAO24 lookup. Route: ${aircraft?.route?.source ?? "unavailable"}. '
            'Same-airframe route inference; aircraft assignment is taken from the selected record, not independently verified. '
            'Route enrichment may be incomplete or outdated. No arrival time or commercial number is inferred.');
  }

  static IncomingState assess(
      TrackedAircraft aircraft, Airport airport, String address, DateTime now,
      {String? expectedRegistration, String? outboundCallsign}) {
    String compact(String s) =>
        s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (aircraft.state.icao24.toLowerCase() != address.toLowerCase() ||
        (expectedRegistration != null &&
            aircraft.identity?.registration != null &&
            compact(expectedRegistration) !=
                compact(aircraft.identity!.registration!)))
      return IncomingState.identityConflict;
    final positionTime = aircraft.state.positionTime;
    if (positionTime == null ||
        now.difference(positionTime) > const Duration(minutes: 2) ||
        positionTime.difference(now) > const Duration(seconds: 30))
      return IncomingState.stale;
    if (aircraft.state.hasGroundState && aircraft.state.onGround) {
      if (airport.latitude == null || airport.longitude == null)
        return IncomingState.routeUnknown;
      final dy = (aircraft.state.latitude - airport.latitude!) * math.pi / 180;
      final dx =
          (aircraft.state.longitude - airport.longitude!) * math.pi / 180;
      final a = math.pow(math.sin(dy / 2), 2) +
          math.cos(airport.latitude! * math.pi / 180) *
              math.cos(aircraft.state.latitude * math.pi / 180) *
              math.pow(math.sin(dx / 2), 2);
      final nm = 3440.065 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
      return nm <= 3
          ? IncomingState.onGroundNearby
          : IncomingState.groundElsewhere;
    }
    if (outboundCallsign != null &&
        outboundCallsign.trim().isNotEmpty &&
        compact(outboundCallsign) == compact(aircraft.state.callsign))
      return IncomingState.sameFlight;
    final destination =
        aircraft.flight?.destination ?? aircraft.route?.destination;
    if (destination == null || !aircraft.state.hasGroundState)
      return IncomingState.routeUnknown;
    return destination.icao.toUpperCase() == airport.icao.toUpperCase()
        ? IncomingState.candidate
        : IncomingState.differentDestination;
  }
}
