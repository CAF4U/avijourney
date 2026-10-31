import 'package:avijourney/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'search_workflows_test.dart' as fixtures;

void main() {
  testWidgets(
      'route search lists results before selection and preserves them on back',
      (tester) async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    await tester.tap(find.byTooltip('Search aircraft, airlines and airports'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('universalSearchField')), 'LHR-EXT');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routeAircraftMap')), findsNothing);
    final row = find.byKey(const Key('searchResult-route-EGLL-EGTE'));
    expect(row, findsOneWidget);
    expect(app.displayFilter, isNull);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    final aircraft = find.byKey(const Key('drilldownAircraft-40621D'));
    expect(aircraft, findsOneWidget);
    await tester.tap(aircraft);
    await tester.pumpAndSettle();
    expect(app.selectedIcao24, '40621D');
    expect(find.text('Registration'), findsOneWidget);
    Navigator.of(tester.element(find.text('Registration'))).pop();
    await tester.pumpAndSettle();
    expect(aircraft, findsOneWidget);
    await tester.tap(find.byKey(const Key('backToSearchResults')));
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('universalSearchField')))
            .controller!
            .text,
        'LHR-EXT');
    expect(app.displayFilter, isNull);
  });

  testWidgets(
      'airline category drills down to matching aircraft without applying a filter',
      (tester) async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    await tester.tap(find.byTooltip('Search aircraft, airlines and airports'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('universalSearchField')), 'British Airways');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final chip = find.byKey(const Key('searchCategory-airline'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('searchResult-airline-BAW')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drilldownAircraft-40621D')), findsOneWidget);
    expect(find.byKey(const Key('drilldownAircraft-4CA123')), findsNothing);
    expect(app.displayFilter, isNull);
  });

  testWidgets(
      'a recognised route with no acquired aircraft still remains a list result',
      (tester) async {
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    await tester.tap(find.byTooltip('Search aircraft, airlines and airports'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('universalSearchField')), 'LHR-LAX');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routeAircraftMap')), findsNothing);
    await tester.tap(find.byKey(const Key('searchResult-route-EGLL-KLAX')));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('This does not mean no aircraft'), findsOneWidget);
    expect(find.byKey(const Key('routeAircraftMap')), findsOneWidget);
  });
}
