import 'dart:math' as math;
import 'package:avijourney/domain/models/tracking_center.dart';
import 'package:avijourney/features/radar/radar_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('radar projection matches a geographic tile camera after zoom and pan',
      () {
    for (final latitude in [0.0, 22.3, 51.47, 75.0]) {
      for (final range in [.25, 10.0, 200.0]) {
        final geometry = RadarGeometry(
            TrackingCenter(latitude: latitude, longitude: -73.8, label: 'Scan'),
            const Offset(2, -1),
            192,
            range);
        final point =
            geometry.position(latitude + .02, -73.75, const Size.square(400));
        // Independent spherical-Mercator equations used by XYZ map tiles.
        double projectedY(double lat) {
          final sinPhi = math.sin(lat * math.pi / 180);
          return 128 - 64 * math.log((1 + sinPhi) / (1 - sinPhi)) / math.pi;
        }

        final scale = math.pow(2, geometry.zoom);
        final expected = const Offset(200, 200) +
            Offset(
                (-73.75 - geometry.center.longitude) / 360 * 256 * scale,
                (projectedY(latitude + .02) -
                        projectedY(geometry.center.latitude)) *
                    scale);
        expect(point.dx, closeTo(expected.dx, .00001));
        expect(point.dy, closeTo(expected.dy, .00001));
      }
    }
  });

  test('nearby targets across the antimeridian remain nearby on the radar', () {
    const geometry = RadarGeometry(
        TrackingCenter(latitude: 0, longitude: 179.9, label: 'Dateline'),
        Offset.zero,
        192,
        20);
    final point = geometry.position(0, -179.9, const Size.square(400));
    expect(point.dx, closeTo(200 + 12 / 20 * 192, .00001));
    expect(point.dy, closeTo(200, .00001));
  });

  test('polar locations produce a finite camera inside the tile projection',
      () {
    const geometry = RadarGeometry(
        TrackingCenter(latitude: 90, longitude: 0, label: 'Pole'),
        Offset(0, 100),
        192,
        200);
    expect(geometry.center.latitude, inInclusiveRange(-85.052, 85.052));
    expect(geometry.zoom.isFinite, isTrue);
  });
}
