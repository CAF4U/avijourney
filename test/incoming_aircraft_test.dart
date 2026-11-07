import 'dart:convert';
import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/app/incoming_aircraft_service.dart';
import 'package:avijourney/data/opensky/opensky_aircraft_position_provider.dart';
import 'package:avijourney/data/repositories/mock_aircraft_repository.dart';
import 'package:avijourney/data/mock/mock_aircraft_provider.dart';
import 'package:avijourney/data/mock/mock_enrichment_provider.dart';
import 'package:avijourney/domain/models/aircraft_identity.dart';
import 'package:avijourney/domain/models/aircraft_state.dart';
import 'package:avijourney/domain/models/airport.dart';
import 'package:avijourney/domain/models/flight_route.dart';
import 'package:avijourney/domain/models/incoming_aircraft.dart';
import 'package:avijourney/domain/models/tracked_aircraft.dart';
import 'package:avijourney/domain/providers/aircraft_lookup_provider.dart';
import 'package:avijourney/domain/providers/aircraft_enrichment_provider.dart';
import 'package:avijourney/features/aircraft_detail/aircraft_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'opensky_provider_test.dart' show stateRow;

const alc = Airport(
    icao: 'LEAL',
    iata: 'ALC',
    name: 'Alicante',
    latitude: 38.2822,
    longitude: -.5582);
const lgw = Airport(
    icao: 'EGKK',
    iata: 'LGW',
    name: 'Gatwick',
    latitude: 51.15,
    longitude: -.19);
const brs = Airport(
    icao: 'EGGD',
    iata: 'BRS',
    name: 'Bristol',
    latitude: 51.38,
    longitude: -2.72);
final now = DateTime.utc(2026, 11, 7, 13, 30);
TrackedAircraft target(
        {String address = '4d22ff',
        String callsign = 'RYR91RL',
        Airport? destination = alc,
        bool ground = false,
        double latitude = 41.1,
        double longitude = -.042,
        DateTime? observed,
        bool timed = true}) =>
    TrackedAircraft(
        state: AircraftState(
            icao24: address,
            callsign: callsign,
            latitude: latitude,
            longitude: longitude,
            altitudeFeet: 31000,
            groundSpeedKnots: 435,
            trackDegrees: 187,
            verticalRateFeetPerMinute: 0,
            observedAt: observed ?? now,
            hasPositionTimestamp: timed,
            onGround: ground),
        identity:
            const AircraftIdentity(icao24: '4d22ff', registration: '9H-VUA'),
        route: destination == null
            ? null
            : FlightRoute(
                callsign: callsign,
                origin: lgw,
                destination: destination,
                source: 'Test route'));

class Positions implements AircraftLookupProvider {
  AircraftState? value = target().state;
  int requests = 0;
  bool fail = false;
  @override
  Future<AircraftState?> fetchByAddress(String icao24) async {
    requests++;
    if (fail) throw Exception('offline');
    return value;
  }
}

class Enrichment implements AircraftEnrichmentProvider {
  bool fail = false;
  @override
  Future<AircraftIdentity?> resolveAircraft(String address) async =>
      target().identity;
  @override
  Future<FlightRoute?> resolveRoute(String callsign) async {
    if (fail) throw Exception('route unavailable');
    return target(callsign: callsign).route;
  }

  @override
  Future<Airport?> resolveAirport(String code) async => alc;
}

void main() {
  test(
      'targeted OpenSky request has only the requested aircraft and no scan bounds',
      () async {
    Uri? uri;
    final provider =
        OpenSkyAircraftPositionProvider(client: MockClient((r) async {
      uri = r.url;
      return http.Response(
          jsonEncode({
            'time': 1700000002,
            'states': [stateRow(icao24: '4d22ff'), stateRow()]
          }),
          200);
    }));
    expect((await provider.fetchByAddress('4D22FF'))!.icao24, '4d22ff');
    expect(uri!.queryParameters, {'icao24': '4d22ff'});
    await expectLater(provider.fetchByAddress(''), throwsArgumentError);
    await expectLater(provider.fetchByAddress('invalid'), throwsArgumentError);
  });

  test(
      'same-address inbound is a candidate; wrong route, callsign and identity are not',
      () {
    IncomingState assess(TrackedAircraft t,
            {String? registration, String? callsign}) =>
        IncomingAircraftService.assess(t, alc, '4d22ff', now,
            expectedRegistration: registration, outboundCallsign: callsign);
    expect(assess(target(), callsign: 'RYR9LW'), IncomingState.candidate);
    expect(
        assess(target(destination: brs)), IncomingState.differentDestination);
    expect(assess(target(destination: null)), IncomingState.routeUnknown);
    expect(assess(target(), callsign: 'RYR91RL'), IncomingState.sameFlight);
    expect(assess(target(address: 'abcdef')), IncomingState.identityConflict);
    expect(assess(target(), registration: '9H-OTHER'),
        IncomingState.identityConflict);
    expect(assess(target(), registration: '9hvua'), IncomingState.candidate);
  });

  test(
      'fresh radio contact cannot turn stale/undated positions into an inbound candidate',
      () {
    for (final t in [
      target(observed: now.subtract(const Duration(minutes: 3))),
      target(timed: false),
      target(observed: now.add(const Duration(minutes: 1)))
    ]) {
      expect(IncomingAircraftService.assess(t, alc, '4d22ff', now),
          IncomingState.stale);
    }
    expect(
        IncomingAircraftService.assess(
            target(
                ground: true,
                latitude: alc.latitude!,
                longitude: alc.longitude!),
            alc,
            '4d22ff',
            now),
        IncomingState.onGroundNearby);
    expect(
        IncomingAircraftService.assess(
            target(ground: true), alc, '4d22ff', now),
        IncomingState.groundElsewhere);
  });

  test(
      'lookup coalesces and caches by address; enrichment failure retains the aircraft',
      () async {
    var clock = now;
    final positions = Positions();
    final enrichment = Enrichment();
    final service = IncomingAircraftService(
        positions: positions, enrichment: enrichment, clock: () => clock);
    final results = await Future.wait([
      service.find(address: '4d22ff', airport: alc),
      service.find(address: '4D22FF', airport: alc)
    ]);
    expect(positions.requests, 1);
    expect(results.first.state, IncomingState.candidate);
    await service.find(address: '4d22ff', airport: brs);
    expect(positions.requests, 1);
    clock = clock.add(const Duration(seconds: 31));
    enrichment.fail = true;
    expect((await service.find(address: '4d22ff', airport: alc)).state,
        IncomingState.routeUnknown);
    expect(positions.requests, 2);
    clock = clock.add(const Duration(seconds: 31));
    positions.fail = true;
    expect((await service.find(address: '4d22ff', airport: alc)).state,
        IncomingState.lookupFailed);
    await service.find(address: '4d22ff', airport: alc);
    expect(positions.requests, 3);
  });

  testWidgets(
      'outbound card finds same-airframe incoming leg and maps it without changing scan or alerts',
      (tester) async {
    final service = IncomingAircraftService(
        positions: Positions(), enrichment: Enrichment(), clock: () => now);
    final app = AppController(
        repository: MockAircraftRepository(
            positions: const MockAircraftPositionProvider(),
            enrichment: const MockAircraftEnrichmentProvider()),
        incomingService: service);
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    final before = app.aircraft.length;
    final center = app.trackingCenter;
    final outbound = TrackedAircraft(
        state: target(callsign: 'RYR9LW').state,
        identity: target().identity,
        route: const FlightRoute(
            callsign: 'RYR9LW', origin: alc, destination: brs));
    showAircraftDetail(
        tester.element(find.byKey(const Key('radarCanvas'))), outbound, app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('findIncomingAircraft')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lookupIncomingAircraft')));
    await tester.pumpAndSettle();
    expect(find.text('Likely incoming aircraft'), findsOneWidget);
    final map = find.byKey(const Key('showIncomingOnMap'));
    await tester.ensureVisible(map);
    await tester.tap(map);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mapMarker-4d22ff')), findsOneWidget);
    expect(find.byKey(const Key('routeConnectionLayer')), findsOneWidget);
    expect(app.aircraft.length, before);
    expect(app.trackingCenter, same(center));
    expect(app.alerts, isEmpty);
    expect(app.mapAircraft.single.state.callsign, 'RYR91RL');
    await tester.tap(find.byTooltip('Clear incoming aircraft'));
    await tester.pumpAndSettle();
    expect(app.incomingMapTarget, isNull);
  });
}
