import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/app/mapping/map_viewport_controller.dart';
import 'package:avijourney/data/local/bundled_airport_search_provider.dart';
import 'package:avijourney/data/local/static_airport_search_provider.dart';
import 'package:avijourney/data/repositories/mock_aircraft_repository.dart';
import 'package:avijourney/data/mock/mock_aircraft_provider.dart';
import 'package:avijourney/data/mock/mock_enrichment_provider.dart';
import 'package:avijourney/domain/models/aircraft_filter.dart';
import 'package:avijourney/domain/models/airline.dart';
import 'package:avijourney/domain/models/search_result.dart';
import 'package:avijourney/domain/models/tracking_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppController controller({bool global = false}) => AppController(
      repository: MockAircraftRepository(
          positions: const MockAircraftPositionProvider(),
          enrichment: const MockAircraftEnrichmentProvider()),
      airportSearchProvider: global
          ? BundledAirportSearchProvider()
          : const StaticAirportSearchProvider(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('query, aircraft and airline filters update shared visible aircraft',
      () async {
    final app = controller();
    addTearDown(app.dispose);
    await app.initialize();
    final total = app.aircraft.length;
    app.setDisplayFilter(const AircraftFilter(label: 'BAW12', query: 'BAW12'));
    expect(app.visibleAircraft, isNotEmpty);
    expect(
        app.visibleAircraft.every((a) => a.state.callsign == 'BAW12'), isTrue);
    final chosen = app.visibleAircraft.first;
    app.setDisplayFilter(
        AircraftFilter(label: 'Aircraft', icao24: chosen.state.icao24));
    expect(app.visibleAircraft, hasLength(1));
    await app.refresh();
    expect(app.visibleAircraft, hasLength(1));
    app.setDisplayFilter(const AircraftFilter(
        label: 'British Airways',
        airline: Airline(name: 'British Airways', icaoCode: 'BAW')));
    expect(app.visibleAircraft, isNotEmpty);
    expect(app.visibleAircraft.every((a) => a.state.callsign.startsWith('BAW')),
        isTrue);
    app.setDisplayFilter(null);
    expect(app.visibleAircraft, hasLength(total));
  });

  test('airport filters distinguish origin, destination and unknown routes',
      () async {
    final app = controller();
    addTearDown(app.dispose);
    await app.initialize();
    final sample = app.aircraft.firstWhere((a) => a.route?.origin != null);
    final origin = sample.route!.origin!;
    final from = AircraftFilter(
        label: 'from', airport: origin, direction: AirportDirection.origin);
    final to = AircraftFilter(
        label: 'to', airport: origin, direction: AirportDirection.destination);
    expect(from.matches(sample, matchesQuery: false), isTrue);
    if (sample.route!.destination?.icao != origin.icao) {
      expect(to.matches(sample, matchesQuery: false), isFalse);
    }
    app.setDisplayFilter(from);
    expect(app.visibleAircraft, contains(sample));
  });

  testWidgets('airport result opens details and recentres radar and map',
      (tester) async {
    final app = controller(global: true);
    final viewport =
        MapViewportController(MapViewport.around(TrackingCenter.heathrow));
    addTearDown(app.dispose);
    addTearDown(viewport.dispose);
    await tester.pumpWidget(AviJourneyApp(
        controller: app, mapViewportController: viewport, showMapTiles: false));
    await tester.pumpAndSettle();
    app.setDisplayFilter(
        const AircraftFilter(label: 'old filter', query: 'BAW12'));
    await tester.tap(find.byTooltip('Search aircraft, airlines and airports'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('universalSearchField')), 'La Guardia');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final airport = app
        .search('La Guardia')
        .firstWhere((r) => r.type == SearchResultType.airport);
    await tester.tap(find.text(airport.title));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trackSelectedAirport')), findsOneWidget);
    await tester.tap(find.byKey(const Key('trackSelectedAirport')));
    await tester.pumpAndSettle();
    expect(app.trackingCenter.label, contains('LGA'));
    expect(viewport.viewport.latitude, app.trackingCenter.latitude);
    expect(viewport.viewport.longitude, app.trackingCenter.longitude);
    expect(app.displayFilter, isNull);
    expect(find.byKey(const Key('rangeBadge')), findsOneWidget);
  });

  testWidgets('submitted search filters radar and can be cleared',
      (tester) async {
    final app = controller();
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search aircraft, airlines and airports'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('universalSearchField')), 'BAW12');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filterSearchResults')));
    await tester.pumpAndSettle();
    expect(app.visibleAircraft, hasLength(1));
    expect(find.byKey(const Key('universalSearchField')), findsNothing);
    await tester.tap(find.byKey(const Key('clearDisplayFilter')));
    await tester.pumpAndSettle();
    expect(app.displayFilter, isNull);
    expect(app.visibleAircraft.length, greaterThan(1));
  });
}
