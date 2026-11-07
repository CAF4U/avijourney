import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/domain/models/aircraft_filter.dart';
import 'package:avijourney/domain/models/aircraft_state.dart';
import 'package:avijourney/domain/models/search_scope.dart';
import 'package:avijourney/domain/models/search_result.dart';
import 'package:avijourney/domain/models/tracked_aircraft.dart';
import 'package:avijourney/domain/repositories/aircraft_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'search_workflows_test.dart' as fixtures;

class ChangingRepository implements AircraftRepository {
  List<TrackedAircraft> aircraft = [];
  int requests = 0;
  @override
  Future<List<TrackedAircraft>> loadNearby(
      {required double centerLatitude,
      required double centerLongitude,
      required double radiusNauticalMiles}) async {
    requests++;
    return aircraft;
  }
}

Future<void> openSearch(WidgetTester tester, AppController app) async {
  await tester.pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
  await tester.pumpAndSettle();
  app.pause();
  await tester.tap(find.byTooltip('Search aircraft, airlines and airports'));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const Key('universalSearchField')), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  test(
      'scope separates worldwide references from acquired aircraft and ignores display filters',
      () async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await app.initialize();
    app.pause();
    app.setDisplayFilter(
        const AircraftFilter(label: 'hide all', query: 'NOMATCH'));
    final area = app.search('British Airways', scope: SearchScope.scanArea);
    expect(area, isNotEmpty);
    expect(
        area.every((r) =>
            r.type == SearchResultType.aircraft ||
            r.type == SearchResultType.flight),
        isTrue);
    final reference =
        app.search('British Airways', scope: SearchScope.worldwideReference);
    expect(reference, isNotEmpty);
    expect(
        reference.every((r) =>
            r.type != SearchResultType.aircraft &&
            r.type != SearchResultType.flight),
        isTrue);
    expect(app.visibleAircraft, isEmpty);
    expect(
        app
            .search('LHR-LAX', scope: SearchScope.worldwideReference)
            .where((r) => r.type == SearchResultType.route),
        isNotEmpty);
  });

  testWidgets(
      'commercial flight empty state explains missing capability and keeps search separate from filters',
      (tester) async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await openSearch(tester, app);
    await submit(tester, 'FR2291');
    final message =
        find.textContaining('This looks like a commercial flight number');
    await tester.ensureVisible(message);
    expect(message, findsOneWidget);
    expect(app.displayFilter, isNull);
    final coverage = find.byKey(const Key('searchCoverage'));
    await tester.ensureVisible(coverage);
    expect(find.textContaining('London Heathrow'), findsWidgets);
    final help = find.byKey(const Key('searchCapabilities'));
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'automatic incoming-aircraft identification are not connected yet'),
        findsOneWidget);
  });

  testWidgets(
      'switching scopes and submitting a new query clears a stale category',
      (tester) async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await openSearch(tester, app);
    await submit(tester, 'British Airways');
    final category = find.byKey(const Key('searchCategory-airline'));
    await tester.ensureVisible(category);
    await tester.tap(category);
    await submit(tester, 'LHR-EXT');
    final route = find.byKey(const Key('searchResult-route-EGLL-EGTE'));
    await tester.ensureVisible(route);
    expect(route, findsOneWidget);
    final area = find.byKey(const Key('searchScope-scanArea'));
    await tester.ensureVisible(area);
    await tester.tap(area);
    await tester.pumpAndSettle();
    expect(route, findsNothing);
    expect(app.displayFilter, isNull);
    final worldwide = find.byKey(const Key('searchScope-worldwideReference'));
    await tester.ensureVisible(worldwide);
    await tester.tap(worldwide);
    await tester.pumpAndSettle();
    await tester.ensureVisible(route);
    expect(route, findsOneWidget);
    expect(find.byKey(const Key('filterSearchResults')), findsNothing);
  });

  testWidgets(
      'submitted search updates after aircraft refresh without retyping or querying while typing',
      (tester) async {
    final repository = ChangingRepository();
    final app = AppController(repository: repository);
    addTearDown(app.dispose);
    await openSearch(tester, app);
    final initialRequests = repository.requests;
    await submit(tester, 'RYR91RL');
    expect(repository.requests, initialRequests);
    repository.aircraft = [
      TrackedAircraft(
          state: AircraftState(
              icao24: '4d22ff',
              callsign: 'RYR91RL',
              latitude: app.trackingCenter.latitude,
              longitude: app.trackingCenter.longitude,
              altitudeFeet: 31000,
              groundSpeedKnots: 435,
              trackDegrees: 187,
              verticalRateFeetPerMinute: 0,
              observedAt: DateTime.utc(2026, 11, 7, 13, 30)))
    ];
    await app.refresh();
    await tester.pumpAndSettle();
    final result = find.byKey(const Key('searchResult-aircraft-4d22ff'));
    await tester.ensureVisible(result);
    expect(result, findsOneWidget);
    expect(repository.requests, initialRequests + 1);
  });
}
