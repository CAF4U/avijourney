import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/models/tracking_center.dart';

/// One Web Mercator camera for both radar targets and geographic tiles.
/// Offsets are projected nautical miles at the scan centre's latitude.
class RadarGeometry {
  const RadarGeometry(
      this.scanCenter, this.offsetNm, this.radius, this.rangeNm);
  final TrackingCenter scanCenter;
  final Offset offsetNm;
  final double radius;
  final double rangeNm;

  static double worldY(double latitude) {
    final phi = latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    return (1 - math.log(math.tan(math.pi / 4 + phi / 2)) / math.pi) / 2;
  }

  double get _circumference =>
      21600 *
      math.cos(
          scanCenter.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180);
  double get _centerX =>
      (scanCenter.longitude + 180) / 360 + offsetNm.dx / _circumference;
  double get _centerY =>
      (worldY(scanCenter.latitude) - offsetNm.dy / _circumference)
          .clamp(0.0, 1.0);
  double get worldPixels => radius * _circumference / rangeNm;
  double get zoom => math.log(worldPixels / 256) / math.ln2;
  LatLng get center => LatLng(
      (2 * math.atan(math.exp((1 - 2 * _centerY) * math.pi)) - math.pi / 2) *
          180 /
          math.pi,
      ((_centerX * 360) % 360) - 180);

  Offset position(double latitude, double longitude, Size size) {
    final dx = ((longitude + 180) / 360 - _centerX + .5) % 1 - .5;
    return size.center(Offset.zero) +
        Offset(dx * worldPixels, (worldY(latitude) - _centerY) * worldPixels);
  }
}
