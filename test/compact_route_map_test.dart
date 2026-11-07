import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/mapping/map_viewport_controller.dart';
import 'package:avijourney/domain/models/aircraft_route.dart';
import 'package:avijourney/domain/models/app_settings.dart';
import 'package:avijourney/domain/models/search_result.dart';
import 'package:avijourney/domain/models/tracking_center.dart';
import 'package:avijourney/features/map/aircraft_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'search_workflows_test.dart' as fixtures;

void main() {
  for (final appearance in AppAppearance.values) {
    testWidgets(
        'route summary collapses on a phone, clears filter and leaves map space in ${appearance.name}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final app = fixtures.controller();
      addTearDown(app.dispose);
      final viewport =
          MapViewportController(MapViewport.around(TrackingCenter.heathrow));
      addTearDown(viewport.dispose);
      app.updateSettings(app.settings.copyWith(mapAppearance: appearance));
      await tester.pumpWidget(AviJourneyApp(
          controller: app,
          mapViewportController: viewport,
          showMapTiles: false));
      await tester.pumpAndSettle();
      app.pause();
      final route = app
          .search('LHR-EXT')
          .singleWhere((r) => r.type == SearchResultType.route)
          .value as AircraftRoute;
      app.showRoute(route, onMap: true);
      viewport.update(
          MapViewport(latitude: 51, longitude: -2, zoom: 7, route: route));
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      final summary = find.byKey(const Key('routeMapSummary'));
      final collapsed = tester.getSize(summary).height;
      expect(collapsed, lessThan(64));
      expect(find.byKey(const Key('routeSummaryDetails')), findsNothing);
      expect(find.text('Clear filter'), findsNothing);
      expect(find.byKey(const Key('clearDisplayFilter')), findsOneWidget);
      final surface = tester.widget<Material>(summary);
      expect(surface.color!.opacity, lessThan(1));
      await tester.tap(find.byKey(const Key('routeSummaryToggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('routeSummaryDetails')), findsOneWidget);
      expect(tester.getSize(summary).height, greaterThan(collapsed));
      await tester.tap(find.byKey(const Key('routeSummaryToggle')));
      await tester.pumpAndSettle();
      expect(tester.getSize(summary).height, collapsed);
      final point = find.byKey(const ValueKey('routeAirportPoint-EGLL'));
      final airportLabel = find.text('LHR');
      expect(tester.getRect(airportLabel).top,
          greaterThan(tester.getCenter(point).dy));
      final target = find.byWidgetPredicate((w) => w is AircraftMapMarker);
      final marker = tester.widget<AircraftMapMarker>(target);
      final icon =
          find.byKey(ValueKey('mapMarkerIcon-${marker.aircraft.state.icao24}'));
      expect(tester.getCenter(icon), tester.getCenter(target));
      expect(tester.getSize(icon).longestSide, lessThan(30));
      await tester.tap(find.byKey(const Key('clearDisplayFilter')));
      await tester.pumpAndSettle();
      expect(app.mapRoute, isNull);
      expect(app.displayFilter, isNull);
      expect(summary, findsNothing);
    });
  }
}
