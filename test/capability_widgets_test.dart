import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/domain/models/app_settings.dart';
import 'package:avijourney/domain/models/airport.dart';
import 'package:avijourney/features/weather/airport_weather_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'airport_weather_test.dart' as weather;
import 'foreground_alerts_test.dart' as alerts;

void main() {
  testWidgets(
      'airport weather switch fetches reports independently of alerts on a phone',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final provider = weather.FakeWeather();
    final app = AppController(
        repository: alerts.SequenceRepository(), weatherProvider: provider);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    openAirportWeather(tester.element(find.byKey(const Key('radarCanvas'))),
        const Airport(icao: 'EGLL', iata: 'LHR', name: 'Heathrow'), app);
    await tester.pumpAndSettle();
    expect(provider.calls, 0);
    await tester.tap(find.byKey(const Key('airportWeatherCapabilitySwitch')));
    await tester.pumpAndSettle();
    expect(provider.calls, 2);
    expect(app.settings.foregroundAlerts, isFalse);
    expect(find.text('METAR · OBSERVATION'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('TAF · FORECAST'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('TAF · FORECAST'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
  testWidgets(
      'fresh events show a dismissible in-app banner and retained history without enabling weather',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var now = alerts.epoch;
    final repo = alerts.SequenceRepository()..values = [alerts.observation(0)];
    final app = AppController(
        repository: repo, trackingCenter: alerts.center, clock: () => now);
    app.toggleSaved('abc123');
    app.updateSettings(const AppSettings(foregroundAlerts: true));
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    now = alerts.epoch.add(const Duration(seconds: 30));
    repo.values = [alerts.observation(30, ground: false)];
    await app.refresh();
    await tester.pumpAndSettle();
    now = alerts.epoch.add(const Duration(seconds: 60));
    repo.values = [alerts.observation(60, ground: false, squawk: '7700')];
    await app.refresh();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('foregroundAlertBanner')), findsOneWidget);
    expect(app.alerts, hasLength(2));
    expect(app.settings.airportWeather, isFalse);
    await tester.tap(find.byTooltip('Dismiss alert banner'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('foregroundAlertBanner')), findsNothing);
    await tester.tap(find.byTooltip('Foreground alerts'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('foregroundAlertsPage')), findsOneWidget);
    await tester.tap(find.byKey(const Key('alertsCapabilitySwitch')));
    await tester.pumpAndSettle();
    expect(app.settings.foregroundAlerts, isFalse);
    expect(app.alerts, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
