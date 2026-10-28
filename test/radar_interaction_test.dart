import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/data/mock/mock_aircraft_provider.dart';
import 'package:avijourney/data/mock/mock_enrichment_provider.dart';
import 'package:avijourney/data/repositories/mock_aircraft_repository.dart';
import 'package:avijourney/features/radar/radar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('radar shows north and tapping an aircraft opens detail',
      (tester) async {
    final controller = AppController(
      repository: MockAircraftRepository(
        positions: const MockAircraftPositionProvider(),
        enrichment: const MockAircraftEnrichmentProvider(),
      ),
      feedName: 'Mock feed',
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    controller.pause();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RadarView(
          controller: controller,
          onOpenTrackingLocation: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('radarNorthIndicator')), findsOneWidget);
    expect(find.text('N'), findsOneWidget);

    final canvas = find.byKey(const Key('radarCanvas'));
    final size = tester.getSize(canvas);
    final target = controller.visibleAircraft.firstWhere((aircraft) {
      final candidate = RadarPainter.positionFor(
        aircraft,
        controller.trackingCenter,
        size,
        controller.settings.radarRangeNm,
      );
      return (candidate - size.center(Offset.zero)).distance <
          size.shortestSide / 2;
    });
    final point = RadarPainter.positionFor(target, controller.trackingCenter,
        size, controller.settings.radarRangeNm);
    await tester.tapAt(tester.getTopLeft(canvas) + point);
    await tester.pumpAndSettle();

    expect(controller.selectedIcao24, target.state.icao24);
    expect(find.text('AIRCRAFT'), findsOneWidget);
    expect(find.text(target.state.icao24.toUpperCase()), findsOneWidget);
  });
}
