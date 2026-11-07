import 'dart:convert';
import 'package:avijourney/data/opensky/opensky_aircraft_position_provider.dart';
import 'package:avijourney/app/alerts/foreground_alert_engine.dart';
import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/domain/models/aircraft_alert.dart';
import 'package:avijourney/domain/models/aircraft_state.dart';
import 'package:avijourney/domain/models/app_settings.dart';
import 'package:avijourney/domain/models/tracked_aircraft.dart';
import 'package:avijourney/domain/models/tracking_center.dart';
import 'package:avijourney/domain/repositories/aircraft_repository.dart';
import 'package:avijourney/data/local/shared_preferences_app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final epoch = DateTime.utc(2026, 10, 31, 12);
const center = TrackingCenter(latitude: 0, longitude: 0, label: 'Test');
TrackedAircraft observation(int seconds,
        {String id = 'abc123',
        bool ground = true,
        bool known = true,
        double lat = 0,
        double lon = 0,
        String? squawk,
        double altitude = 0,
        double speed = 0,
        bool positionKnown = true}) =>
    TrackedAircraft(
        state: AircraftState(
            icao24: id,
            callsign: 'TEST1',
            latitude: lat,
            longitude: lon,
            altitudeFeet: altitude,
            groundSpeedKnots: speed,
            trackDegrees: 0,
            verticalRateFeetPerMinute: 0,
            observedAt: epoch.add(Duration(seconds: seconds)),
            onGround: ground,
            hasGroundState: known,
            hasPositionTimestamp: positionKnown,
            squawk: squawk));
List<AircraftAlert> process(
        ForegroundAlertEngine engine, List<TrackedAircraft> list, int seconds,
        {AppSettings settings = const AppSettings(foregroundAlerts: true),
        Set<String> followed = const {'ABC123'}}) =>
    engine.process(
        aircraft: list,
        center: center,
        settings: settings,
        followed: followed,
        now: epoch.add(Duration(seconds: seconds)));

class SequenceRepository implements AircraftRepository {
  List<TrackedAircraft> values = [];
  bool fail = false;
  @override
  Future<List<TrackedAircraft>> loadNearby(
      {required double centerLatitude,
      required double centerLongitude,
      required double radiusNauticalMiles}) async {
    if (fail) throw StateError('offline');
    return values;
  }
}

void main() {
  test('fresh radio contact does not make an old position fresh', () {
    final states = OpenSkyAircraftPositionProvider.parseResponse(jsonEncode({
      'time': epoch.add(const Duration(seconds: 300)).millisecondsSinceEpoch ~/
          1000,
      'states': [
        [
          'abc123',
          'TEST',
          'GB',
          epoch.millisecondsSinceEpoch ~/ 1000,
          epoch.add(const Duration(seconds: 300)).millisecondsSinceEpoch ~/
              1000,
          0,
          0,
          0,
          false,
          100,
          0,
          0,
          null,
          0,
          '7700',
          false,
          0
        ]
      ]
    }));
    expect(states.single.observedAt, epoch.add(const Duration(seconds: 300)));
    expect(states.single.positionTime, epoch);
    expect(
        process(ForegroundAlertEngine(),
            [TrackedAircraft(state: states.single)], 300),
        isEmpty);
  });
  test(
      'baseline does not flood; later followed detection uses circle not bounding box',
      () {
    final e = ForegroundAlertEngine();
    expect(process(e, [observation(0)], 0), isEmpty);
    expect(process(e, [observation(60, id: 'other')], 60), isEmpty);
    expect(process(e, [observation(120, lat: .3, lon: .3)], 120), isEmpty);
    expect(process(e, [observation(180)], 180).single.kind,
        AircraftAlertKind.detected);
    expect(process(e, [observation(180)], 180), isEmpty);
    expect(process(e, [], 200), isEmpty);
    expect(process(e, [observation(240)], 240), isEmpty);
  });
  test(
      'squawk reports deduplicate and respect followed-only and master switches',
      () {
    final e = ForegroundAlertEngine();
    expect(process(e, [observation(0, squawk: '7700')], 0).single.kind,
        AircraftAlertKind.squawk7700);
    expect(process(e, [observation(60, squawk: '7700')], 60), isEmpty);
    expect(process(e, [observation(120, squawk: '7600')], 120).single.kind,
        AircraftAlertKind.squawk7600);
    expect(
        process(ForegroundAlertEngine(), [observation(0, squawk: '7700')], 0,
            followed: {},
            settings: const AppSettings(
                foregroundAlerts: true, alertSquawkFollowedOnly: true)),
        isEmpty);
    expect(
        process(ForegroundAlertEngine(), [observation(0, squawk: '7700')], 0,
            settings: const AppSettings()),
        isEmpty);
  });
  test(
      'stale, future, unknown position timestamps and out-of-order samples never alert',
      () {
    final e = ForegroundAlertEngine();
    expect(process(e, [observation(0, squawk: '7700')], 200), isEmpty);
    expect(process(e, [observation(300, squawk: '7700')], 200), isEmpty);
    expect(
        process(
            e, [observation(200, squawk: '7700', positionKnown: false)], 200),
        isEmpty);
    process(e, [observation(210)], 210);
    expect(process(e, [observation(209, squawk: '7700')], 211), isEmpty);
  });
  test(
      'takeoff and landing require two unique confirming samples; not zero altitude thresholds',
      () {
    final e = ForegroundAlertEngine();
    process(e, [observation(0, ground: true, altitude: 5000)], 0);
    expect(
        process(e, [observation(30, ground: false, altitude: 0)], 30), isEmpty);
    expect(process(e, [observation(30, ground: false)], 35), isEmpty);
    expect(process(e, [observation(60, ground: false)], 60).single.kind,
        AircraftAlertKind.takeoffInferred);
    expect(process(e, [observation(90, ground: true)], 90), isEmpty);
    expect(process(e, [observation(120, ground: true)], 120).single.kind,
        AircraftAlertKind.landingInferred);
    expect(
        estimatedMovement(observation(0, ground: true, altitude: 5000).state,
            now: epoch),
        contains('Stationary on ground'));
    expect(
        estimatedMovement(observation(0, ground: false, altitude: 0).state,
            now: epoch),
        contains('Airborne'));
  });
  test('gaps and missing surface state reset motion evidence', () {
    final e = ForegroundAlertEngine();
    process(e, [observation(0)], 0);
    expect(process(e, [observation(300, ground: false)], 300), isEmpty);
    expect(process(e, [observation(330, known: false)], 330), isEmpty);
    expect(process(e, [observation(360, ground: false)], 360), isEmpty);
    e.resetBaseline();
    expect(process(e, [observation(390)], 390), isEmpty);
  });
  test(
      'alerts and history persist; weather toggle is independent; cached failures and background suppress events',
      () async {
    SharedPreferences.setMockInitialValues({});
    var now = epoch;
    final repo = SequenceRepository()..values = [observation(0)];
    final app = AppController(
        repository: repo,
        trackingCenter: center,
        preferencesStore: const SharedPreferencesAppStore(),
        clock: () => now);
    addTearDown(app.dispose);
    app.updateSettings(const AppSettings(foregroundAlerts: true));
    await app.refresh();
    now = epoch.add(const Duration(seconds: 30));
    repo.values = [observation(30, ground: false)];
    await app.refresh();
    app.updateSettings(app.settings.copyWith(airportWeather: true));
    now = epoch.add(const Duration(seconds: 60));
    repo.values = [observation(60, ground: false, squawk: '7700')];
    // Follow the aircraft without inserting a fake entry event.
    // Motion above is intentionally unfollowed; squawk remains available for all aircraft.
    await app.refresh();
    expect(app.alerts.single.kind, AircraftAlertKind.squawk7700);
    repo.fail = true;
    await app.refresh();
    expect(app.alerts, hasLength(1));
    app.pause();
    repo.fail = false;
    repo.values = [observation(90, squawk: '7600')];
    now = epoch.add(const Duration(seconds: 90));
    await app.refresh();
    expect(app.alerts, hasLength(1));
    app.updateSettings(app.settings.copyWith(airportWeather: false));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final saved = (await const SharedPreferencesAppStore().load())!;
    expect(saved.settings.foregroundAlerts, isTrue);
    expect(saved.settings.airportWeather, isFalse);
    expect(saved.alerts.single.kind, AircraftAlertKind.squawk7700);
  });
  test('changing weather does not reset followed movement evidence', () async {
    var now = epoch;
    final repo = SequenceRepository()..values = [observation(0)];
    final app = AppController(
        repository: repo, trackingCenter: center, clock: () => now);
    addTearDown(app.dispose);
    app.toggleSaved('abc123');
    app.updateSettings(const AppSettings(foregroundAlerts: true));
    await app.refresh();
    now = epoch.add(const Duration(seconds: 30));
    repo.values = [observation(30, ground: false)];
    await app.refresh();
    app.updateSettings(app.settings.copyWith(airportWeather: true));
    now = epoch.add(const Duration(seconds: 60));
    repo.values = [observation(60, ground: false)];
    await app.refresh();
    expect(app.alerts.single.kind, AircraftAlertKind.takeoffInferred);
  });
}
