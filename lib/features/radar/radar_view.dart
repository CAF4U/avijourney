import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/mapping/map_tile_source.dart';
import 'radar_geometry.dart';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/manual_refresh_button.dart';
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
    this.tileSource,
    this.showTiles = true,
    this.onShowMap,
    super.key,
  });
  final MapTileSource? tileSource;
  final bool showTiles;
  final VoidCallback? onShowMap;
  final AppController controller;
  final VoidCallback onOpenTrackingLocation;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> {
  AppController get controller => widget.controller;
  double _zoom = 1;
  double _gestureStartZoom = 1;
  Offset _viewOffsetNm = Offset.zero;
  Offset _gestureAnchorNm = Offset.zero;
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
      _viewOffsetNm = Offset.zero;
      _scanRange = controller.settings.radarRangeNm;
      _scanCenter = center;
    }
  }

  Offset _clampOffset(Offset value) {
    final limit = math.max(0.0, controller.settings.radarRangeNm - _viewRange);
    return value.distance > limit && value.distance > 0
        ? value * (limit / value.distance)
        : value;
  }

  void _setZoom(double value) => setState(() {
        _zoom = value.clamp(1.0, _maxZoom).toDouble();
        _viewOffsetNm = _clampOffset(_viewOffsetNm);
      });

  Offset _focalNm(Offset focal, double size) {
    final delta = focal - Offset(size / 2, size / 2);
    final scale = (size / 2 - 8) / _viewRange;
    return Offset(delta.dx / scale, -delta.dy / scale);
  }

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
                  child: Stack(fit: StackFit.expand, children: [
                    if (widget.showTiles && widget.tileSource != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipOval(
                            child: IgnorePointer(
                                child: RadarBasemap(
                          tileSource: widget.tileSource!,
                          geometry: RadarGeometry(controller.trackingCenter,
                              _viewOffsetNm, size / 2 - 8, _viewRange),
                          light:
                              Theme.of(context).brightness == Brightness.light,
                        ))),
                      ),
                    CustomPaint(
                      key: const Key('radarCanvas'),
                      painter: RadarPainter(
                        geographicBackground:
                            widget.showTiles && widget.tileSource != null,
                        aircraft: controller.visibleAircraft,
                        selectedIcao24: controller.selectedIcao24,
                        rangeNm: _viewRange,
                        viewOffsetNm: _viewOffsetNm,
                        showLabels: controller.settings.showLabels,
                        showTrails: controller.settings.showTrails,
                        trackingCenter: controller.trackingCenter,
                        brightness: Theme.of(context).brightness,
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (details) {
                          _gestureStartZoom = _zoom;
                          _gestureAnchorNm = _viewOffsetNm +
                              _focalNm(details.localFocalPoint, size);
                        },
                        onScaleUpdate: (details) => setState(() {
                          _zoom = (_gestureStartZoom * details.scale)
                              .clamp(1.0, _maxZoom)
                              .toDouble();
                          _viewOffsetNm = _clampOffset(_gestureAnchorNm -
                              _focalNm(details.localFocalPoint, size));
                        }),
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
                    const Positioned(
                      key: Key('radarNorthIndicator'),
                      top: 12,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
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
                      left: 18,
                      right: 18,
                      top: size / 2 - 10,
                      child: const IgnorePointer(
                          child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('W',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('E',
                              style: TextStyle(fontWeight: FontWeight.bold))
                        ],
                      )),
                    ),
                    const Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                            child: Center(
                                child: Text('S',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))))),
                    Positioned(
                        top: 46,
                        left: size * .12,
                        child: IgnorePointer(
                            child: _ScopeBadge(
                          text:
                              '${controller.isActive ? controller.feedStatus.name.toUpperCase() : 'PAUSED'} · ${controller.visibleAircraft.length}',
                        ))),
                    if (widget.onShowMap != null)
                      Positioned(
                          top: 40,
                          right: size * .12,
                          child: TextButton.icon(
                              key: const Key('radarMapShortcut'),
                              onPressed: widget.onShowMap,
                              style: TextButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surface
                                      .withOpacity(.9)),
                              icon: const Icon(Icons.map_outlined, size: 16),
                              label: const Text('Open map'))),
                    Positioned(
                        top: 86,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                            child: Center(
                                child: Text(_observationTime,
                                    key: const Key('radarObservationTime'),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold))))),
                  ]),
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
                top: 68,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  child: ManualRefreshButton(
                      controller: controller, surface: 'radar'),
                ),
              ),
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
                    child: Text(
                        '${_viewOffsetNm.distance > .001 ? 'PANNED · ' : ''}VIEW · $_viewRangeLabel NM radius',
                        key: const Key('radarViewRange'),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
              if (widget.showTiles && widget.tileSource != null)
                Positioned(
                    left: 12,
                    right: 12,
                    bottom: 76,
                    child: Center(
                        child: InkWell(
                      onTap: () => unawaited(launchUrl(
                          widget.tileSource!.attributionUri,
                          mode: LaunchMode.externalApplication)),
                      child: Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withOpacity(.9),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 3),
                          child: Text('© ${widget.tileSource!.attributionText}',
                              style: const TextStyle(fontSize: 10))),
                    ))),
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

  String get _observationTime {
    if (controller.aircraft.isEmpty) return 'NO OBSERVATIONS';
    final time = controller.aircraft
        .map((a) => a.state.observedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b)
        .toLocal();
    return 'FIX ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} local';
  }

  TrackedAircraft? _nearestAircraft(Offset tap, Size size) {
    final radius = size.shortestSide / 2 - 8;
    if ((tap - size.center(Offset.zero)).distance > radius) return null;
    TrackedAircraft? nearest;
    var distance = 28.0;
    for (final aircraft in controller.visibleAircraft) {
      final point = RadarPainter.positionFor(
          aircraft, controller.trackingCenter, size, _viewRange,
          viewOffsetNm: _viewOffsetNm);
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
      this.geographicBackground = false,
      this.viewOffsetNm = Offset.zero,
      this.brightness = Brightness.dark});
  final bool geographicBackground;
  final List<TrackedAircraft> aircraft;
  final String? selectedIcao24;
  final double rangeNm;
  final Offset viewOffsetNm;
  final bool showLabels;
  final bool showTrails;
  final TrackingCenter trackingCenter;
  final Brightness brightness;

  static Offset positionFor(TrackedAircraft aircraft,
          TrackingCenter trackingCenter, Size size, num rangeNm,
          {Offset viewOffsetNm = Offset.zero}) =>
      positionForCoordinates(aircraft.state.latitude, aircraft.state.longitude,
          trackingCenter, size, rangeNm,
          viewOffsetNm: viewOffsetNm);

  static Offset positionForCoordinates(double latitude, double longitude,
      TrackingCenter trackingCenter, Size size, num rangeNm,
      {Offset viewOffsetNm = Offset.zero}) {
    return RadarGeometry(trackingCenter, viewOffsetNm,
            size.shortestSide / 2 - 8, rangeNm.toDouble())
        .position(latitude, longitude, size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final light = brightness == Brightness.light;
    final targetColor =
        light ? const Color(0xFF1E5AA8) : const Color(0xFF4CF7DF);
    final selectedColor =
        light ? const Color(0xFF6D1F7B) : const Color(0xFFFFD166);
    final grid = Paint()
      ..color = light ? const Color(0x55315970) : const Color(0xAA35DBDF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (!geographicBackground)
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color =
                light ? const Color(0xFFF4F7FA) : const Color(0xFF07150D));
    final sweepRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
        sweepRect,
        2.6,
        .3,
        true,
        Paint()
          ..shader = SweepGradient(
                  startAngle: 2.6,
                  endAngle: 2.9,
                  colors: [
                    targetColor.withOpacity(0),
                    targetColor.withOpacity(.16)
                  ],
                  tileMode: TileMode.clamp)
              .createShader(sweepRect));
    for (var ring = 1; ring <= 4; ring++)
      canvas.drawCircle(center, radius * ring / 4, grid);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), grid);
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), grid);
    final scanCenter = positionForCoordinates(trackingCenter.latitude,
        trackingCenter.longitude, trackingCenter, size, rangeNm,
        viewOffsetNm: viewOffsetNm);
    if ((scanCenter - center).distance <= radius)
      canvas.drawCircle(scanCenter, 3, Paint()..color = targetColor);
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    for (final target in aircraft) {
      final point = positionFor(target, trackingCenter, size, rangeNm,
          viewOffsetNm: viewOffsetNm);
      if ((point - center).distance > radius) continue;
      final selected = target.state.icao24 == selectedIcao24;
      if (showTrails && target.trail.length > 1) {
        final trailPath = Path();
        for (var index = 0; index < target.trail.length; index++) {
          final observation = target.trail[index];
          final trailPoint = positionForCoordinates(observation.latitude,
              observation.longitude, trackingCenter, size, rangeNm,
              viewOffsetNm: viewOffsetNm);
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
        ..moveTo(0, -11)
        ..lineTo(2, -8)
        ..lineTo(2, -2)
        ..lineTo(10, 4)
        ..lineTo(10, 6)
        ..lineTo(2, 3)
        ..lineTo(2, 8)
        ..lineTo(5, 10)
        ..lineTo(5, 11)
        ..lineTo(0, 9)
        ..lineTo(-5, 11)
        ..lineTo(-5, 10)
        ..lineTo(-2, 8)
        ..lineTo(-2, 3)
        ..lineTo(-10, 6)
        ..lineTo(-10, 4)
        ..lineTo(-2, -2)
        ..lineTo(-2, -8)
        ..close();
      canvas.drawPath(
          marker,
          Paint()
            ..color = light ? Colors.white : const Color(0xFF002D34)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
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
        final label = TextPainter(
            text: TextSpan(
                text: target.primaryIdentifier,
                style: TextStyle(
                    color: selected
                        ? selectedColor
                        : (light ? targetColor : const Color(0xFFD8FBE1)),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr)
          ..layout();
        final labelOrigin = point + const Offset(12, -18);
        canvas.drawRRect(
            RRect.fromRectAndRadius((labelOrigin & label.size).inflate(3),
                const Radius.circular(3)),
            Paint()
              ..color =
                  light ? const Color(0xCCFFFFFF) : const Color(0xCC020E14));
        label.paint(canvas, labelOrigin);
      }
    }
    canvas.restore();
    for (final target
        in aircraft.where((a) => a.state.icao24 == selectedIcao24)) {
      final point = positionFor(target, trackingCenter, size, rangeNm,
          viewOffsetNm: viewOffsetNm);
      if ((point - center).distance > radius) continue;
      final width = math.min(210.0, radius * 1.15);
      final rect = Rect.fromLTWH(
          center.dx - width * .12, center.dy - radius * .55, width, 76);
      canvas.drawLine(
          point,
          rect.bottomLeft,
          Paint()
            ..color = selectedColor
            ..strokeWidth = 1);
      final box = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(
          box,
          Paint()
            ..color =
                light ? const Color(0xEEFFFFFF) : const Color(0xEE020E14));
      canvas.drawRRect(
          box,
          Paint()
            ..color = selectedColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      final model = target.identity?.model ??
          target.identity?.typeCode ??
          'Type unavailable';
      TextPainter(
          text: TextSpan(
              style: TextStyle(
                  fontSize: 11, color: light ? Colors.black : Colors.white),
              children: [
                TextSpan(
                    text: '${target.primaryIdentifier}\n',
                    style: TextStyle(
                        color: selectedColor, fontWeight: FontWeight.bold)),
                TextSpan(
                    text:
                        '$model\n${target.state.altitudeFeet.round()} ft · HDG ${target.state.trackDegrees.round()}°')
              ]),
          textDirection: TextDirection.ltr,
          maxLines: 4,
          ellipsis: '…')
        ..layout(maxWidth: width - 16)
        ..paint(canvas, rect.topLeft + const Offset(8, 6));
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) =>
      oldDelegate.geographicBackground != geographicBackground ||
      oldDelegate.brightness != brightness ||
      oldDelegate.aircraft != aircraft ||
      oldDelegate.selectedIcao24 != selectedIcao24 ||
      oldDelegate.rangeNm != rangeNm ||
      oldDelegate.viewOffsetNm != viewOffsetNm ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.showTrails != showTrails ||
      oldDelegate.trackingCenter != trackingCenter;
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(.9),
          border: Border.all(color: const Color(0xFF35DBDF)),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)));
}

class RadarBasemap extends StatefulWidget {
  const RadarBasemap(
      {required this.tileSource,
      required this.geometry,
      required this.light,
      super.key});
  final MapTileSource tileSource;
  final RadarGeometry geometry;
  final bool light;
  @override
  State<RadarBasemap> createState() => _RadarBasemapState();
}

class _RadarBasemapState extends State<RadarBasemap> {
  final _map = MapController();
  bool _ready = false;
  @override
  void didUpdateWidget(covariant RadarBasemap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(widget.geometry.center, widget.geometry.zoom);
      });
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FlutterMap(
        mapController: _map,
        options: MapOptions(
            initialCenter: widget.geometry.center,
            initialZoom: widget.geometry.zoom,
            minZoom: 0,
            maxZoom: 24,
            backgroundColor: widget.light
                ? const Color(0xFFF4F7FA)
                : const Color(0xFF07151D),
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
            onMapReady: () => _ready = true),
        children: [
          TileLayer(
              urlTemplate: widget.tileSource.urlTemplate,
              userAgentPackageName: widget.tileSource.userAgentPackageName,
              maxNativeZoom: widget.tileSource.maximumNativeZoom,
              tileBuilder: widget.light ? null : darkModeTileBuilder)
        ],
      );
}
