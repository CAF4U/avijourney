import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/screen_appearance_toggle.dart';
import '../../domain/models/app_settings.dart';

import '../../app/app_controller.dart';
import '../../domain/models/tracked_aircraft.dart';
import '../../domain/models/tracking_center.dart';
import '../aircraft_detail/aircraft_detail_sheet.dart';

class RadarView extends StatefulWidget {
  const RadarView({
    required this.controller,
    required this.onOpenTrackingLocation,
    super.key,
  });
  final AppController controller;
  final VoidCallback onOpenTrackingLocation;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> {
  AppController get controller => widget.controller;
  double _zoom = 1;
  double _gestureStartZoom = 1;
  late int _scanRange;
  late TrackingCenter _scanCenter;
  double get _maxZoom => controller.settings.radarRangeNm / .25;
  double get _viewRange => controller.settings.radarRangeNm / _zoom;

  @override
  void initState() {
    super.initState();
    _scanRange = controller.settings.radarRangeNm;
    _scanCenter = controller.trackingCenter;
  }

  @override
  void didUpdateWidget(covariant RadarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final center = controller.trackingCenter;
    if (_scanRange != controller.settings.radarRangeNm ||
        _scanCenter.latitude != center.latitude ||
        _scanCenter.longitude != center.longitude) {
      _zoom = 1;
      _scanRange = controller.settings.radarRangeNm;
      _scanCenter = center;
    }
  }

  void _setZoom(double value) =>
      setState(() => _zoom = value.clamp(1.0, _maxZoom).toDouble());

  String get _viewRangeLabel =>
      _viewRange.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context) => Theme(
      data: controller.settings.effectiveRadarAppearance == AppAppearance.dark
          ? AppTheme.dark()
          : AppTheme.light(),
      child: Builder(builder: _buildRadar));

  Widget _buildRadar(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final size = math
            .min(constraints.maxWidth, constraints.maxHeight - 62)
            .clamp(240.0, 720.0);
        return ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Stack(children: [
              Center(
                child: SizedBox.square(
                  dimension: size,
                  child: CustomPaint(
                    key: const Key('radarCanvas'),
                    painter: RadarPainter(
                      aircraft: controller.visibleAircraft,
                      selectedIcao24: controller.selectedIcao24,
                      rangeNm: _viewRange,
                      showLabels: controller.settings.showLabels,
                      showTrails: controller.settings.showTrails,
                      trackingCenter: controller.trackingCenter,
                      brightness: Theme.of(context).brightness,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (_) => _gestureStartZoom = _zoom,
                      onScaleUpdate: (details) =>
                          _setZoom(_gestureStartZoom * details.scale),
                      onTapUp: (details) {
                        final aircraft = _nearestAircraft(
                          details.localPosition,
                          Size.square(size),
                        );
                        if (aircraft == null) {
                          controller.select(null);
                          return;
                        }
                        controller.select(aircraft.state.icao24);
                        showAircraftDetail(context, aircraft, controller);
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                  top: 12,
                  left: 12,
                  child: ScreenAppearanceToggle(
                      screen: 'Radar',
                      value: controller.settings.effectiveRadarAppearance,
                      onChanged: (value) => controller.updateSettings(controller
                          .settings
                          .copyWith(radarAppearance: value)))),
              const Positioned(
                key: Key('radarNorthIndicator'),
                top: 68,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('N',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4)),
                    Icon(Icons.north, size: 17),
                  ]),
                ),
              ),
              Positioned(
                  top: 14,
                  right: 14,
                  child: PopupMenuButton<int>(
                      tooltip: 'Select radar range',
                      initialValue: controller.settings.radarRangeNm,
                      onSelected: controller.setRadarRange,
                      itemBuilder: (_) => const [20, 80, 140, 200]
                          .map((range) => PopupMenuItem(
                              value: range, child: Text('$range NM')))
                          .toList(),
                      child: Container(
                          key: const Key('rangeBadge'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border.all(
                                  color: Theme.of(context).colorScheme.primary),
                              borderRadius: BorderRadius.circular(22)),
                          child: Text('${controller.settings.radarRangeNm} NM',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))))),
              Positioned(
                right: 12,
                bottom: 100,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      key: const Key('radarZoomIn'),
                      tooltip: 'Zoom radar in',
                      onPressed:
                          _zoom < _maxZoom ? () => _setZoom(_zoom * 2) : null,
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      key: const Key('radarZoomOut'),
                      tooltip: 'Zoom radar out',
                      onPressed: _zoom > 1 ? () => _setZoom(_zoom / 2) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      key: const Key('radarZoomReset'),
                      tooltip: 'Show full radar scan area',
                      onPressed: () => _setZoom(1),
                      icon: const Icon(Icons.center_focus_strong),
                    ),
                  ]),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 100,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Theme.of(context).colorScheme.surface,
                    child: Text('VIEW · $_viewRangeLabel NM radius',
                        key: const Key('radarViewRange'),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
              Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      key: const Key('radarCenterControl'),
                      onTap: widget.onOpenTrackingLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          const Icon(Icons.edit_location_alt_outlined,
                              size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Text(
                                    'CENTRE · ${controller.trackingCenter.label}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'Tap to change · ${controller.feedName} position feed',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10)),
                              ])),
                          const Icon(Icons.chevron_right, size: 20),
                        ]),
                      ),
                    ),
                  )),
            ]));
      });

  TrackedAircraft? _nearestAircraft(Offset tap, Size size) {
    final radius = size.shortestSide / 2 - 8;
    if ((tap - size.center(Offset.zero)).distance > radius) return null;
    TrackedAircraft? nearest;
    var distance = 28.0;
    for (final aircraft in controller.visibleAircraft) {
      final point = RadarPainter.positionFor(
          aircraft, controller.trackingCenter, size, _viewRange);
      final candidate = (tap - point).distance;
      if (candidate < distance &&
          (point - size.center(Offset.zero)).distance <= radius) {
        distance = candidate;
        nearest = aircraft;
      }
    }
    return nearest;
  }
}

class RadarPainter extends CustomPainter {
  RadarPainter(
      {required this.aircraft,
      required this.selectedIcao24,
      required this.rangeNm,
      required this.showLabels,
      required this.showTrails,
      required this.trackingCenter,
      this.brightness = Brightness.dark});
  final List<TrackedAircraft> aircraft;
  final String? selectedIcao24;
  final double rangeNm;
  final bool showLabels;
  final bool showTrails;
  final TrackingCenter trackingCenter;
  final Brightness brightness;

  static Offset positionFor(TrackedAircraft aircraft,
          TrackingCenter trackingCenter, Size size, num rangeNm) =>
      positionForCoordinates(aircraft.state.latitude, aircraft.state.longitude,
          trackingCenter, size, rangeNm);

  static Offset positionForCoordinates(double latitude, double longitude,
      TrackingCenter trackingCenter, Size size, num rangeNm) {
    const nmPerLatitudeDegree = 60.0;
    final longitudeNm = (longitude - trackingCenter.longitude) *
        60 *
        math.cos(trackingCenter.latitude * math.pi / 180);
    final latitudeNm =
        (latitude - trackingCenter.latitude) * nmPerLatitudeDegree;
    final scale = (size.shortestSide / 2 - 8) / rangeNm;
    return Offset(size.width / 2 + longitudeNm * scale,
        size.height / 2 - latitudeNm * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final light = brightness == Brightness.light;
    final targetColor =
        light ? const Color(0xFF1E5AA8) : const Color(0xFF89F7A8);
    final selectedColor =
        light ? const Color(0xFF6D1F7B) : const Color(0xFFFFD166);
    final grid = Paint()
      ..color = light ? const Color(0x55315970) : const Color(0x5569E58B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = light ? const Color(0xFFF4F7FA) : const Color(0xFF07150D));
    for (var ring = 1; ring <= 4; ring++)
      canvas.drawCircle(center, radius * ring / 4, grid);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), grid);
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), grid);
    canvas.drawCircle(center, 3, Paint()..color = targetColor);
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    for (final target in aircraft) {
      final point = positionFor(target, trackingCenter, size, rangeNm);
      if ((point - center).distance > radius) continue;
      final selected = target.state.icao24 == selectedIcao24;
      if (showTrails && target.trail.length > 1) {
        final trailPath = Path();
        for (var index = 0; index < target.trail.length; index++) {
          final observation = target.trail[index];
          final trailPoint = positionForCoordinates(observation.latitude,
              observation.longitude, trackingCenter, size, rangeNm);
          if (index == 0) {
            trailPath.moveTo(trailPoint.dx, trailPoint.dy);
          } else {
            trailPath.lineTo(trailPoint.dx, trailPoint.dy);
          }
        }
        canvas.drawPath(
            trailPath,
            Paint()
              ..color = (selected ? selectedColor : targetColor).withOpacity(.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = selected ? 2 : 1);
      }
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(target.state.trackDegrees * math.pi / 180);
      final marker = Path()
        ..moveTo(0, -9)
        ..lineTo(6, 8)
        ..lineTo(0, 5)
        ..lineTo(-6, 8)
        ..close();
      canvas.drawPath(
          marker, Paint()..color = selected ? selectedColor : targetColor);
      if (selected)
        canvas.drawCircle(
            Offset.zero,
            14,
            Paint()
              ..color = selectedColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      canvas.restore();
      if (showLabels && (rangeNm <= 80 || selected)) {
        TextPainter(
            text: TextSpan(
                text: target.primaryIdentifier,
                style: TextStyle(
                    color: selected
                        ? selectedColor
                        : (light ? targetColor : const Color(0xFFD8FBE1)),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr)
          ..layout()
          ..paint(canvas, point + const Offset(9, -15));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) =>
      oldDelegate.brightness != brightness ||
      oldDelegate.aircraft != aircraft ||
      oldDelegate.selectedIcao24 != selectedIcao24 ||
      oldDelegate.rangeNm != rangeNm ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.showTrails != showTrails ||
      oldDelegate.trackingCenter != trackingCenter;
}
