import 'package:avijourney/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shell navigates and exposes quick radar range choices',
      (tester) async {
    await tester.pumpWidget(
        const AviJourneyApp(showMapTiles: false, useLiveData: false));
    await tester.pumpAndSettle();
    expect(find.text('CAF4U Aircraft Companion'), findsOneWidget);
    expect(find.text('20 NM'), findsOneWidget);
    expect(find.textContaining('CENTER · LONDON HEATHROW'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rangeBadge')));
    await tester.pumpAndSettle();
    expect(find.text('80 NM'), findsOneWidget);
    await tester.tap(find.text('80 NM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aircraftGeographicMap')), findsOneWidget);
  });

  testWidgets('settings labels the recommended interval as 60 seconds',
      (tester) async {
    await tester.pumpWidget(
        const AviJourneyApp(showMapTiles: false, useLiveData: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filters and settings'));
    await tester.pumpAndSettle();

    expect(find.text('60 seconds (recommended)'), findsOneWidget);
    expect(find.textContaining('Milestone 1 mock provider'), findsNothing);
    await tester.scrollUntilVisible(
        find.textContaining('Mock feed · live'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Mock feed · live'), findsOneWidget);
  });

  testWidgets('universal search waits for submission', (tester) async {
    await tester.pumpWidget(
        const AviJourneyApp(showMapTiles: false, useLiveData: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search aircraft, airlines and airports'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('universalSearchField')), 'BAW12');
    await tester.pump();
    expect(find.text('FLIGHTS'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('FLIGHTS'), findsOneWidget);
    expect(find.text('AIRCRAFT'), findsOneWidget);
  });

  testWidgets('search guidance examples are clickable and discover globally',
      (tester) async {
    await tester.pumpWidget(
        const AviJourneyApp(showMapTiles: false, useLiveData: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search aircraft, airlines and airports'));
    await tester.pumpAndSettle();

    expect(find.text('TRY AN EXAMPLE'), findsOneWidget);
    expect(
        find.textContaining('airports and airlines worldwide'), findsOneWidget);
    final example = find.byKey(const Key('searchExample-JFK'));
    await tester.ensureVisible(example);
    await tester.tap(example);
    await tester.pumpAndSettle();

    expect(find.text('AIRPORTS'), findsOneWidget);
    expect(find.textContaining('John F. Kennedy'), findsOneWidget);
  });

  testWidgets('Radar Cards and Saved navigation continues to share state',
      (tester) async {
    await tester.pumpWidget(
        const AviJourneyApp(showMapTiles: false, useLiveData: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rangeBadge')), findsOneWidget);

    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(find.text('BAW12'), findsOneWidget);
    await tester.tap(find.byTooltip('Save aircraft').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('BAW12'), findsOneWidget);
  });
}
