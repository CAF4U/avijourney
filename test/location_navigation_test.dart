import 'dart:async';

import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/app/mapping/map_viewport_controller.dart';
import 'package:avijourney/data/local/static_airport_search_provider.dart';
import 'package:avijourney/domain/models/followed_item.dart';
import 'package:avijourney/domain/models/tracked_aircraft.dart';
import 'package:avijourney/domain/models/tracking_center.dart';
import 'package:avijourney/domain/repositories/aircraft_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'search_workflows_test.dart' as fixtures;

MapCamera camera(WidgetTester tester) => tester
    .widget<FlutterMap>(
        find.byKey(const Key('aircraftGeographicMap'), skipOffstage: false))
    .mapController!
    .camera;

void expectCamera(WidgetTester tester, double lat, double lon) {
  expect(camera(tester).center.latitude, closeTo(lat, .00001));
  expect(camera(tester).center.longitude, closeTo(lon, .00001));
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.tap(find.byTooltip('Search aircraft, airlines and airports'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('universalSearchField')), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

class BlockingRepository implements AircraftRepository {
  int calls = 0;
  final next = Completer<List<TrackedAircraft>>();
  @override
  Future<List<TrackedAircraft>> loadNearby(
      {required double centerLatitude,
      required double centerLongitude,
      required double radiusNauticalMiles}) async {
    if (++calls == 1) return const [];
    return next.future;
  }
}

void main() {
  testWidgets('settings airport selection moves actual camera after manual pan',
      (tester) async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const Key('aircraftGeographicMap')), const Offset(70, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filters and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tracking location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose airport'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Manchester');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manchester Airport'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expectCamera(tester, 53.3537, -2.275);
    await tester.drag(
        find.byKey(const Key('aircraftGeographicMap')), const Offset(60, 25));
    await tester.pumpAndSettle();
    final panned = camera(tester).center;
    await app.refresh();
    await tester.pumpAndSettle();
    expectCamera(tester, panned.latitude, panned.longitude);
  });

  testWidgets(
      'scan centre moves hidden map immediately while acquisition waits',
      (tester) async {
    final repository = BlockingRepository();
    final app = AppController(repository: repository);
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    final update = app.setTrackingCenter(const TrackingCenter(
        latitude: 40.7772,
        longitude: -73.8726,
        label: 'La Guardia',
        type: TrackingCenterType.map));
    await tester.pump();
    expectCamera(tester, 40.7772, -73.8726);
    expect(repository.next.isCompleted, isFalse);
    repository.next.complete(const []);
    await update;
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expectCamera(tester, 40.7772, -73.8726);
  });

  testWidgets(
      'radar location shortcut offers saved airports and airport search',
      (tester) async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    app.toggleFollowed(const FollowedItem(
        type: FollowedItemType.airport,
        identifier: 'EGCC',
        label: 'Manchester'));
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    await tester.tap(find.byKey(const Key('radarCenterControl')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quickAirport-EGCC')));
    await tester.pumpAndSettle();
    expect(app.trackingCenter.label, contains('MAN'));
    expectCamera(tester, 53.3537, -2.275);
    await tester.tap(find.byKey(const Key('radarCenterControl')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose airport'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'La Guardia');
    await tester.pumpAndSettle();
    final airport = app.searchAirports('La Guardia').single;
    await tester.tap(find.text(airport.name));
    await tester.pumpAndSettle();
    expectCamera(tester, airport.latitude!, airport.longitude!);
    expect(find.byKey(const Key('radarCenterControl')), findsOneWidget);
  });

  for (final type in ['aircraft', 'flight']) {
    testWidgets('$type search result opens map at selected observed position',
        (tester) async {
      final app = fixtures.controller();
      final viewport =
          MapViewportController(MapViewport.around(TrackingCenter.heathrow));
      addTearDown(app.dispose);
      addTearDown(viewport.dispose);
      await tester.pumpWidget(AviJourneyApp(
          controller: app,
          mapViewportController: viewport,
          showMapTiles: false));
      await tester.pumpAndSettle();
      app.pause();
      final target =
          app.aircraft.firstWhere((a) => a.state.callsign == 'BAW12');
      await search(tester, 'BAW12');
      final result = app.search('BAW12').firstWhere((r) => r.type.name == type);
      final row = find.byKey(Key('searchResult-$type-${result.identifier}'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('universalSearchField')), findsNothing);
      expect(find.byKey(const Key('aircraftGeographicMap')), findsOneWidget);
      expect(app.selectedIcao24, target.state.icao24);
      expectCamera(tester, target.state.latitude, target.state.longitude);
      expect(find.byKey(ValueKey('mapMarker-${target.state.icao24}')),
          findsOneWidget);
    });
  }

  testWidgets(
      'airport result information button preserves filters and map action',
      (tester) async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    await search(tester, 'MAN');
    await tester.tap(find.byKey(const Key('searchDetails-airport-EGCC')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trackSelectedAirport')), findsOneWidget);
    expect(find.text('From or to'), findsOneWidget);
    await tester.tap(find.byKey(const Key('trackSelectedAirport')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aircraftGeographicMap')), findsOneWidget);
    expectCamera(tester, 53.3537, -2.275);
  });

  test('saved airport resolution never substitutes a partial match', () {
    final app = AppController(
        repository: BlockingRepository(),
        airportSearchProvider: const StaticAirportSearchProvider());
    addTearDown(app.dispose);
    app.toggleFollowed(const FollowedItem(
        type: FollowedItemType.airport,
        identifier: 'Lond',
        label: 'Invalid old airport'));
    app.toggleFollowed(const FollowedItem(
        type: FollowedItemType.airport,
        identifier: 'EGCC',
        label: 'Manchester'));
    expect(app.savedAirports.map((a) => a.icao), ['EGCC']);
  });
}
