import 'dart:async';
import 'package:avijourney/app/app.dart';
import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/domain/models/aircraft_state.dart';
import 'package:avijourney/domain/models/tracked_aircraft.dart';
import 'package:avijourney/domain/repositories/aircraft_repository.dart';
import 'package:avijourney/features/aircraft_detail/aircraft_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

class RefreshRepository implements AircraftRepository {
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;
  double? latitude, longitude;
  @override
  Future<List<TrackedAircraft>> loadNearby(
      {required double centerLatitude,
      required double centerLongitude,
      required double radiusNauticalMiles}) async {
    calls++;
    latitude = centerLatitude;
    longitude = centerLongitude;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('offline');
    return [
      TrackedAircraft(
          state: AircraftState(
              icao24: 'abc123',
              callsign: 'TEST1',
              latitude: centerLatitude + .01,
              longitude: centerLongitude,
              altitudeFeet: 1000,
              groundSpeedKnots: (calls * 10).toDouble(),
              trackDegrees: 0,
              verticalRateFeetPerMinute: 0,
              observedAt: DateTime.now()))
    ];
  }
}

void main() {
  test(
      'manual requests coalesce while busy and retain the shared ten second limit after failure',
      () async {
    var now = DateTime.utc(2026, 10, 31);
    final repo = RefreshRepository()..gate = Completer<void>();
    final c = AppController(repository: repo, clock: () => now);
    addTearDown(c.dispose);
    final a = c.manualRefresh();
    final b = c.manualRefresh();
    expect(repo.calls, 1);
    expect(c.isRefreshing, isTrue);
    now = now.add(const Duration(seconds: 10));
    expect(c.canManuallyRefresh, isFalse);
    repo.gate!.complete();
    await Future.wait([a, b]);
    expect(c.canManuallyRefresh, isTrue);
    repo.fail = true;
    await c.manualRefresh();
    expect(repo.calls, 2);
    expect(c.feedStatus, FeedStatus.cached);
    expect(c.aircraft, isNotEmpty);
    now = now.add(const Duration(seconds: 9));
    await c.manualRefresh();
    expect(repo.calls, 2);
    expect(c.manualRefreshSecondsRemaining, 1);
    now = now.add(const Duration(seconds: 1));
    repo.fail = false;
    await c.manualRefresh();
    expect(repo.calls, 3);
    c.pause();
    await c.manualRefresh();
    expect(repo.calls, 3);
  });

  testWidgets(
      'Radar, Map and live detail share cooldown and detail updates its metrics',
      (tester) async {
    var now = DateTime.utc(2026, 10, 31);
    final repo = RefreshRepository();
    final c = AppController(repository: repo, clock: () => now);
    await tester.pumpWidget(AviJourneyApp(controller: c, showMapTiles: false));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    await tester.tap(find.byKey(const Key('manualRefresh-radar')));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('manualRefresh-map')))
            .onPressed,
        isNull);
    showAircraftDetail(
        tester.element(find.byKey(const Key('aircraftGeographicMap'))),
        c.aircraft.single,
        c);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('manualRefresh-metrics')), 250,
        scrollable: find.byType(Scrollable).last);
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('manualRefresh-metrics')))
            .onPressed,
        isNull);
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    await tester.tap(find.byKey(const Key('manualRefresh-metrics')));
    await tester.pumpAndSettle();
    expect(repo.calls, 3);
    expect(find.text('30 kt'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(
                find.byKey(const Key('manualRefresh-map'), skipOffstage: false))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });

  testWidgets('moving map offers Track here without acquiring until selected',
      (tester) async {
    final repo = RefreshRepository();
    final c = AppController(repository: repo);
    await tester.pumpWidget(AviJourneyApp(controller: c, showMapTiles: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    final oldCenter = c.trackingCenter;
    await tester.drag(
        find.byKey(const Key('aircraftGeographicMap')), const Offset(90, 60));
    await tester.pumpAndSettle();
    expect(find.text('Track here'), findsOneWidget);
    expect(c.trackingCenter, same(oldCenter));
    expect(repo.calls, 1);
    final camera = tester
        .widget<FlutterMap>(find.byKey(const Key('aircraftGeographicMap')))
        .mapController!
        .camera;
    final target = camera.center;
    final zoom = camera.zoom;
    await tester.tap(find.byKey(const Key('trackMapHere')));
    await tester.pumpAndSettle();
    expect(c.trackingCenter.latitude, closeTo(target.latitude, .000001));
    expect(c.trackingCenter.longitude, closeTo(target.longitude, .000001));
    expect(repo.latitude, c.trackingCenter.latitude);
    expect(repo.longitude, c.trackingCenter.longitude);
    expect(repo.calls, 2);
    expect(find.text('Track here'), findsNothing);
    final updated = tester
        .widget<FlutterMap>(find.byKey(const Key('aircraftGeographicMap')))
        .mapController!
        .camera;
    expect(updated.zoom, zoom);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
