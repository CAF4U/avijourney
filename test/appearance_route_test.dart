import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/persistence/app_preferences_store.dart';
import 'package:avijourney/data/local/shared_preferences_app_store.dart';
import 'package:avijourney/domain/models/app_settings.dart';
import 'package:avijourney/domain/models/aircraft_route.dart';
import 'package:avijourney/domain/models/search_result.dart';
import 'package:avijourney/domain/models/tracking_center.dart';
import 'package:avijourney/features/radar/radar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'search_workflows_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appearance persists and older installs default to dark', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesAppStore();
    expect((await store.load())!.settings.appearance, AppAppearance.dark);
    await store.save(const PersistedAppState(
        trackingCenter: TrackingCenter.heathrow,
        settings: AppSettings(appearance: AppAppearance.light),
        savedAircraft: {}));
    expect(
        (await const SharedPreferencesAppStore().load())!.settings.appearance,
        AppAppearance.light);
    expect(
        const AppSettings(appearance: AppAppearance.light)
            .copyWith(showLabels: false)
            .appearance,
        AppAppearance.light);
  });

  test('reference route exists with no live aircraft; direction is exact',
      () async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await app.initialize();
    final route = app
        .search('LHR-LAX')
        .singleWhere((r) => r.type == SearchResultType.route)
        .value as AircraftRoute;
    expect(route.origin.iata, 'LHR');
    expect(route.destination.iata, 'LAX');
    app.showRoute(route, onMap: false);
    expect(app.visibleAircraft, isEmpty);
    expect(app.mapRoute, isNull);
    final forward = app
        .search('LHR → EXT')
        .singleWhere((r) => r.type == SearchResultType.route)
        .value as AircraftRoute;
    app.showRoute(forward, onMap: true);
    expect(app.visibleAircraft, hasLength(1));
    expect(app.mapRoute!.identifier, 'EGLL-EGTE');
    final reverse = app
        .search('EXT -> LHR')
        .singleWhere((r) => r.type == SearchResultType.route)
        .value as AircraftRoute;
    app.showRoute(reverse, onMap: true);
    expect(app.visibleAircraft, isEmpty);
    app.setDisplayFilter(null);
    expect(app.mapRoute, isNull);
    expect(app.visibleAircraft.length, greaterThan(1));
    expect(app.search('ZZZ-XXX'), isEmpty);
  });

  testWidgets(
      'settings switch appearance immediately and keep other controls live',
      (tester) async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    await tester.tap(find.byTooltip('Filters and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byKey(const Key('appearanceSetting')),
        matching: find.text('Light')));
    await tester.pumpAndSettle();
    expect(app.settings.appearance, AppAppearance.light);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light);
    final painter = tester
        .widget<CustomPaint>(find.byKey(const Key('radarCanvas')))
        .painter as RadarPainter;
    expect(painter.brightness, Brightness.light);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('appearanceSetting')),
        matching: find.text('Dark')));
    await tester.pumpAndSettle();
    expect(app.settings.appearance, AppAppearance.dark);
  });

  for (final onMap in [false, true]) {
    testWidgets(
        'route prompt opens ${onMap ? 'map with connection and aircraft' : 'aircraft list'}',
        (tester) async {
      final app = fixtures.controller();
      addTearDown(app.dispose);
      await tester
          .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
      await tester.pumpAndSettle();
      app.pause();
      await tester
          .tap(find.byTooltip('Search aircraft, airlines and airports'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('universalSearchField')), 'LHR-EXT');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('routeAircraftList')), findsNothing);
      expect(app.displayFilter, isNull);
      await tester
          .ensureVisible(find.byKey(const Key('searchResult-route-EGLL-EGTE')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('searchResult-route-EGLL-EGTE')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('drilldownAircraft-40621D')), findsOneWidget);
      expect(find.byKey(const Key('routeAircraftList')), findsOneWidget);
      expect(find.byKey(const Key('routeAircraftMap')), findsOneWidget);
      await tester.tap(
          find.byKey(Key(onMap ? 'routeAircraftMap' : 'routeAircraftList')));
      await tester.pumpAndSettle();
      expect(app.visibleAircraft, hasLength(1));
      if (onMap) {
        expect(find.byKey(const Key('routeConnectionLayer')), findsOneWidget);
        final layer = tester.widget<PolylineLayer>(
            find.byKey(const Key('routeConnectionLayer')));
        expect(layer.polylines.single.points.first.latitude,
            closeTo(51.4706, .01));
        expect(
            layer.polylines.single.points.last.latitude, closeTo(50.7344, .01));
      } else {
        expect(find.text('BAW12'), findsOneWidget);
        expect(find.textContaining('British Airways'), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('clearDisplayFilter')));
      await tester.pumpAndSettle();
      expect(app.mapRoute, isNull);
      expect(app.visibleAircraft.length, greaterThan(1));
    });
  }
}
