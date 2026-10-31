import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/data/mock/mock_aircraft_provider.dart';
import 'package:avijourney/data/mock/mock_enrichment_provider.dart';
import 'package:avijourney/data/repositories/mock_aircraft_repository.dart';
import 'package:avijourney/domain/models/aircraft_state.dart';
import 'package:avijourney/domain/models/tracking_center.dart';
import 'package:avijourney/features/radar/radar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CountingPositions extends MockAircraftPositionProvider {
  int requests = 0;
  @override
  Future<List<AircraftState>> fetchAircraft({
    required double centerLatitude,
    required double centerLongitude,
    required double radiusNauticalMiles,
  }) {
    requests++;
    return super.fetchAircraft(
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        radiusNauticalMiles: radiusNauticalMiles);
  }
}

RadarPainter painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const Key('radarCanvas'))).painter!
        as RadarPainter;

Future<AppController> mountRadar(
    WidgetTester tester, CountingPositions positions) async {
  final controller = AppController(
      repository: MockAircraftRepository(
          positions: positions,
          enrichment: const MockAircraftEnrichmentProvider()));
  await controller.initialize();
  controller.pause();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: AnimatedBuilder(
              animation: controller,
              builder: (_, __) => RadarView(
                  controller: controller, onOpenTrackingLocation: () {})))));
  return controller;
}

void main() {
  testWidgets(
      'zoom separates targets without enlarging markers or acquiring data; tap uses displayed positions',
      (tester) async {
    final positions = CountingPositions();
    final controller = await mountRadar(tester, positions);
    final requests = positions.requests;
    final canvas = find.byKey(const Key('radarCanvas'));
    final size = tester.getSize(canvas);
    final target = controller.visibleAircraft.first;
    final original = RadarPainter.positionFor(
        target, controller.trackingCenter, size, painter(tester).rangeNm);
    await tester.tap(find.byKey(const Key('radarZoomIn')));
    await tester.pump();
    expect(painter(tester).rangeNm, 10);
    expect(find.text('VIEW · 10 NM radius'), findsOneWidget);
    expect(controller.settings.radarRangeNm, 20);
    expect(positions.requests, requests);
    final zoomed = RadarPainter.positionFor(
        target, controller.trackingCenter, size, painter(tester).rangeNm);
    expect((zoomed - size.center(Offset.zero)).distance,
        closeTo((original - size.center(Offset.zero)).distance * 2, .001));
    await tester.tapAt(tester.getTopLeft(canvas) + zoomed);
    await tester.pumpAndSettle();
    expect(controller.selectedIcao24, target.state.icao24);
    expect(find.text('AIRCRAFT'), findsOneWidget);
  });

  testWidgets(
      'pinch zoom works on a phone, clamps to airport detail scale and resets',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final positions = CountingPositions();
    await mountRadar(tester, positions);
    final center = tester.getCenter(find.byKey(const Key('radarCanvas')));
    final first =
        await tester.startGesture(center - const Offset(35, 0), pointer: 1);
    final second =
        await tester.startGesture(center + const Offset(35, 0), pointer: 2);
    await tester.pump();
    await first.moveTo(center - const Offset(90, 0));
    await second.moveTo(center + const Offset(90, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    expect(painter(tester).rangeNm, lessThan(20));
    expect(find.text('AIRCRAFT'), findsNothing);
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byKey(const Key('radarZoomIn')));
      await tester.pump();
    }
    expect(painter(tester).rangeNm, .25);
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('radarZoomIn')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const Key('radarZoomOut')));
    await tester.pump();
    expect(painter(tester).rangeNm, .5);
    await tester.tap(find.byKey(const Key('radarZoomReset')));
    await tester.pump();
    expect(painter(tester).rangeNm, 20);
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('radarZoomOut')))
            .onPressed,
        isNull);
    expect(positions.requests, 1);
  });

  testWidgets(
      'refresh preserves zoom while changing scan centre or scan range restores full area',
      (tester) async {
    final controller = await mountRadar(tester, CountingPositions());
    await tester.tap(find.byKey(const Key('radarZoomIn')));
    await tester.pump();
    await controller.refresh();
    await tester.pump();
    expect(painter(tester).rangeNm, 10);
    controller.setRadarRange(80);
    await tester.pump();
    expect(painter(tester).rangeNm, 80);
    await tester.tap(find.byKey(const Key('radarZoomIn')));
    await tester.pump();
    expect(painter(tester).rangeNm, 40);
    controller.setTrackingCenter(const TrackingCenter(
        latitude: 40.7769, longitude: -73.8740, label: 'LaGuardia'));
    await tester.pump();
    expect(painter(tester).rangeNm, 80);
  });
}
