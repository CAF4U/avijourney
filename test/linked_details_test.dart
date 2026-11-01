import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/discovery/airport_traffic.dart';
import 'package:avijourney/data/local/bundled_airport_search_provider.dart';
import 'package:avijourney/data/local/bundled_airline_search_provider.dart';
import 'package:avijourney/domain/models/airport.dart';
import 'package:avijourney/domain/models/aircraft_state.dart';
import 'package:avijourney/domain/models/tracked_aircraft.dart';
import 'package:avijourney/features/aircraft_detail/aircraft_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'search_workflows_test.dart' as fixtures;

TrackedAircraft position({double lat = 51.47, bool ground = true}) =>
    TrackedAircraft(
        state: AircraftState(
            icao24: 'ABC123',
            callsign: 'TEST',
            latitude: lat,
            longitude: -.4619,
            altitudeFeet: 0,
            groundSpeedKnots: 0,
            trackDegrees: 0,
            verticalRateFeetPerMinute: 0,
            onGround: ground,
            observedAt: DateTime.utc(2026)));

Future<void> startDetails(WidgetTester tester, {bool phone = false}) async {
  if (phone) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }
  final app = fixtures.controller();
  addTearDown(app.dispose);
  await tester.pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
  await tester.pumpAndSettle();
  app.pause();
  showAircraftDetail(tester.element(find.byKey(const Key('radarCanvas'))),
      app.aircraft.firstWhere((a) => a.state.callsign == 'BAW12'), app);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
      'ground airport list uses both reported ground state and actual distance',
      () {
    const airport = Airport(
        icao: 'EGLL', name: 'Heathrow', latitude: 51.4706, longitude: -.4619);
    expect(matchesAirportTraffic(position(), airport, AirportTraffic.ground),
        isTrue);
    expect(
        matchesAirportTraffic(
            position(ground: false), airport, AirportTraffic.ground),
        isFalse);
    expect(
        matchesAirportTraffic(
            position(lat: 52), airport, AirportTraffic.ground),
        isFalse);
    expect(
        matchesAirportTraffic(
            position(),
            const Airport(icao: 'XXXX', name: 'Unknown'),
            AirportTraffic.ground),
        isFalse);
    expect(matchesAirportTraffic(position(), airport, AirportTraffic.arrivals),
        isFalse);
  });

  test(
      'catalogue enrichment preserves unknown identity and exposes available metadata',
      () async {
    final airports = BundledAirportSearchProvider();
    final airlines = BundledAirlineSearchProvider();
    await airports.initialize();
    await airlines.initialize();
    expect(airports.search('EGLL').firstWhere((a) => a.icao == 'EGLL').type,
        'large_airport');
    expect(airlines.airlines.firstWhere((a) => a.icaoCode == 'VIR').country,
        'United Kingdom');
    final app = fixtures.controller();
    addTearDown(app.dispose);
    expect(app.operatorDetails('British Airways').icaoCode, 'BAW');
    expect(app.operatorDetails('British').icaoCode, isNull);
    expect(app.operatorDetails('Private Owner').name, 'Private Owner');
    final airport =
        app.airportDetails(const Airport(icao: 'EGLL', name: 'Heathrow'));
    expect(airport.latitude, isNotNull);
    expect(
        app
            .airportDetails(const Airport(icao: 'XXXX', name: 'Unknown'))
            .latitude,
        isNull);
  });

  testWidgets(
      'aircraft heading opens physical profile and operator opens linked details',
      (tester) async {
    await startDetails(tester, phone: true);
    await tapVisible(tester, 'detailTitle-AIRCRAFT');
    expect(find.byKey(const Key('aircraftProfilePage')), findsOneWidget);
    expect(find.text('G-EUYA'), findsWidgets);
    await tapVisible(tester, 'detail-PHYSICAL AIRCRAFT-Operator');
    expect(find.byKey(const Key('operatorDetailPage')), findsOneWidget);
    expect(find.text('BAW'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aircraftProfilePage')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detailTitle-AIRCRAFT')), findsOneWidget);
  });

  testWidgets('route heading closes detail overlays and shows geographic route',
      (tester) async {
    await startDetails(tester);
    await tapVisible(tester, 'detailTitle-ROUTE');
    expect(find.byKey(const Key('aircraftGeographicMap')), findsOneWidget);
    expect(find.byKey(const Key('routeConnectionLayer')), findsOneWidget);
    expect(find.byKey(const Key('detailTitle-AIRCRAFT')), findsNothing);
  });

  testWidgets(
      'airport fields open general info, observed boards, search and airport map',
      (tester) async {
    await startDetails(tester, phone: true);
    await tapVisible(tester, 'detail-ROUTE-Origin');
    expect(find.byKey(const Key('airportDetailPage')), findsOneWidget);
    expect(find.text('London Heathrow Airport'), findsOneWidget);
    expect(find.text('EGLL'), findsOneWidget);
    await tapVisible(tester, 'airportArrivals');
    expect(find.text('OBSERVED ARRIVALS'), findsOneWidget);
    expect(find.byKey(const Key('airportAircraft-4CA123')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, 'airportDepartures');
    expect(find.text('OBSERVED DEPARTURES'), findsOneWidget);
    expect(find.byKey(const Key('airportAircraft-40621D')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, 'findDepartingFlight');
    await tester.enterText(
        find.byKey(const Key('airportFlightSearch')), 'does not exist');
    await tester.pumpAndSettle();
    expect(find.textContaining('No matching aircraft in acquired data'),
        findsOneWidget);
    tester.testTextInput.hide();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, 'airportShowMap');
    expect(find.byKey(const Key('aircraftGeographicMap')), findsOneWidget);
    final map = tester
        .widget<FlutterMap>(find.byKey(const Key('aircraftGeographicMap')));
    expect(map.mapController!.camera.center.latitude, closeTo(51.4706, .0001));
  });

  testWidgets('operator field opens operator catalogue details directly',
      (tester) async {
    await startDetails(tester);
    await tapVisible(tester, 'detail-AIRCRAFT-Operator');
    expect(find.byKey(const Key('operatorDetailPage')), findsOneWidget);
    expect(find.text('British Airways'), findsWidgets);
    expect(find.text('BAW'), findsOneWidget);
  });

  testWidgets('model field opens aircraft profile', (tester) async {
    await startDetails(tester);
    await tapVisible(tester, 'detail-AIRCRAFT-Model / type');
    expect(find.byKey(const Key('aircraftProfilePage')), findsOneWidget);
  });
}
