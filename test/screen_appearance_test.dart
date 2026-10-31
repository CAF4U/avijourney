import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/persistence/app_preferences_store.dart';
import 'package:avijourney/data/local/shared_preferences_app_store.dart';
import 'package:avijourney/domain/models/app_settings.dart';
import 'package:avijourney/domain/models/tracking_center.dart';
import 'package:avijourney/features/radar/radar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_workflows_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('screen overrides persist independently and reset removes them',
      () async {
    SharedPreferences.setMockInitialValues({'appearance': 'light'});
    const store = SharedPreferencesAppStore();
    final legacy = (await store.load())!.settings;
    expect(legacy.effectiveRadarAppearance, AppAppearance.light);
    expect(legacy.effectiveMapAppearance, AppAppearance.light);
    final settings = legacy
        .copyWith(
            radarAppearance: AppAppearance.dark,
            mapAppearance: AppAppearance.light)
        .copyWith(showLabels: false);
    await store.save(PersistedAppState(
        trackingCenter: TrackingCenter.heathrow,
        settings: settings,
        savedAircraft: {}));
    final loaded = (await const SharedPreferencesAppStore().load())!.settings;
    expect(loaded.effectiveRadarAppearance, AppAppearance.dark);
    expect(loaded.effectiveMapAppearance, AppAppearance.light);
    expect(loaded.appearance, AppAppearance.light);
    await store.save(const PersistedAppState(
        trackingCenter: TrackingCenter.heathrow,
        settings: AppSettings(),
        savedAircraft: {}));
    final reset = (await store.load())!.settings;
    expect(reset.radarAppearance, isNull);
    expect(reset.mapAppearance, isNull);
  });

  testWidgets(
      'dark radar and light map coexist and survive tab navigation on a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = fixtures.controller();
    addTearDown(app.dispose);
    await tester
        .pumpWidget(AviJourneyApp(controller: app, showMapTiles: false));
    await tester.pumpAndSettle();
    app.pause();
    Future<void> choose(String screen, String label) async {
      await tester.tap(find.descendant(
          of: find.byKey(Key('${screen}AppearanceToggle')),
          matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await choose('radar', 'Light');
    await choose('radar', 'Dark');
    expect(app.settings.radarAppearance, AppAppearance.dark);
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    await choose('map', 'Light');
    expect(app.settings.mapAppearance, AppAppearance.light);
    expect(
        Theme.of(tester.element(find.byKey(const Key('aircraftGeographicMap'))))
            .brightness,
        Brightness.light);
    await tester.tap(find.text('Radar'));
    await tester.pumpAndSettle();
    final painter = tester
        .widget<CustomPaint>(find.byKey(const Key('radarCanvas')))
        .painter as RadarPainter;
    expect(painter.brightness, Brightness.dark);
    expect(app.settings.effectiveMapAppearance, AppAppearance.light);
    app.updateSettings(app.settings.copyWith(appearance: AppAppearance.light));
    await tester.pumpAndSettle();
    expect(app.settings.effectiveRadarAppearance, AppAppearance.dark);
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(
        Theme.of(tester.element(find.byKey(const Key('aircraftGeographicMap'))))
            .brightness,
        Brightness.light);
  });
}
