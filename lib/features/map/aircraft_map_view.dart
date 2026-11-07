import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/manual_refresh_button.dart';
import '../../core/theme/screen_appearance_toggle.dart';
import '../../domain/models/app_settings.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_controller.dart';
import '../../app/mapping/map_tile_source.dart';
import '../../app/mapping/map_viewport_controller.dart';
import '../../domain/models/tracked_aircraft.dart';
import '../../domain/models/tracking_center.dart';
import '../../domain/models/aircraft_route.dart';
import '../aircraft_detail/aircraft_detail_sheet.dart';

class AircraftMapView extends StatefulWidget {
  const AircraftMapView({
    required this.controller,
    required this.viewportController,
    required this.tileSource,
    this.showTiles = true,
    this.mapController,
    super.key,
  });

  final AppController controller;
  final MapViewportController viewportController;
  final MapTileSource tileSource;
  final bool showTiles;
  final MapController? mapController;

  @override
  State<AircraftMapView> createState() => _AircraftMapViewState();
}

class _AircraftMapViewState extends State<AircraftMapView>
    with AutomaticKeepAliveClientMixin {
  late final MapController _mapController =
      widget.mapController ?? MapController();
  late double _zoom = widget.viewportController.viewport.zoom;
  bool _mapReady = false;
  bool _showTrackHere = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.viewportController.addListener(_moveToExternalViewport);
  }

  @override
  void didUpdateWidget(covariant AircraftMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportController != widget.viewportController) {
      oldWidget.viewportController.removeListener(_moveToExternalViewport);
      widget.viewportController.addListener(_moveToExternalViewport);
    }
  }

  void _moveToExternalViewport() {
    if (!_mapReady) return;
    if (_showTrackHere) setState(() => _showTrackHere = false);
    final viewport = widget.viewportController.viewport;
    if (viewport.route case final route? when route.hasCoordinates) {
      _mapController.fitCamera(_routeFit(route));
      return;
    }
    _mapController.move(
      LatLng(viewport.latitude, viewport.longitude),
      viewport.zoom,
    );
  }

  CameraFit _routeFit(AircraftRoute route) => CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([
        LatLng(route.origin.latitude!, route.origin.longitude!),
        LatLng(route.destination.latitude!, route.destination.longitude!),
        ...widget.controller.visibleAircraft
            .map((a) => LatLng(a.state.latitude, a.state.longitude)),
      ]),
      padding: const EdgeInsets.fromLTRB(64, 120, 72, 88),
      maxZoom: 8);

  @override
  void dispose() {
    widget.viewportController.removeListener(_moveToExternalViewport);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Theme(
        data: widget.controller.settings.effectiveMapAppearance ==
                AppAppearance.dark
            ? AppTheme.dark()
            : AppTheme.light(),
        child: Builder(builder: _buildMap));
  }

  Widget _buildMap(BuildContext context) {
    final viewport = widget.viewportController.viewport;
    final route = widget.controller.mapRoute;
    final light = Theme.of(context).brightness == Brightness.light;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          FlutterMap(
            key: const Key('aircraftGeographicMap'),
            mapController: _mapController,
            options: MapOptions(
              onMapReady: () {
                _mapReady = true;
                _moveToExternalViewport();
              },
              initialCenter: LatLng(viewport.latitude, viewport.longitude),
              initialZoom: viewport.zoom,
              minZoom: 1,
              initialCameraFit:
                  viewport.route != null && viewport.route!.hasCoordinates
                      ? _routeFit(viewport.route!)
                      : null,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.flingAnimation,
              ),
              onLongPress: (_, point) => _setCenterFromMap(point),
              onPositionChanged: (camera, hasGesture) {
                widget.viewportController.updateFromMap(MapViewport(
                  latitude: camera.center.latitude,
                  longitude: camera.center.longitude,
                  zoom: camera.zoom,
                ));
                final scan = widget.controller.trackingCenter;
                final away = const Distance().as(LengthUnit.Meter,
                        LatLng(scan.latitude, scan.longitude), camera.center) >
                    100;
                final show = hasGesture ? away : _showTrackHere && away;
                if ((_zoom >= 9) != (camera.zoom >= 9) ||
                    show != _showTrackHere) {
                  setState(() {
                    _zoom = camera.zoom;
                    _showTrackHere = show;
                  });
                } else {
                  _zoom = camera.zoom;
                }
              },
            ),
            children: [
              if (widget.showTiles)
                TileLayer(
                  urlTemplate: widget.tileSource.urlTemplate,
                  userAgentPackageName: widget.tileSource.userAgentPackageName,
                  maxNativeZoom: widget.tileSource.maximumNativeZoom,
                  tileBuilder: light ? null : darkModeTileBuilder,
                ),
              if (route != null && route.hasCoordinates) ...[
                PolylineLayer(
                    key: const Key('routeConnectionLayer'),
                    polylines: [
                      Polyline(
                          points: [
                            LatLng(route.origin.latitude!,
                                route.origin.longitude!),
                            LatLng(route.destination.latitude!,
                                route.destination.longitude!)
                          ],
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 3),
                    ]),
                MarkerLayer(markers: [
                  for (final entry
                      in [route.origin, route.destination].asMap().entries)
                    Marker(
                      key: ValueKey('routeAirport-${entry.value.icao}'),
                      point:
                          LatLng(entry.value.latitude!, entry.value.longitude!),
                      width: 144,
                      height: 80,
                      child: IgnorePointer(
                          child: Stack(children: [
                        Positioned(
                            left: 68,
                            top: 36,
                            child: Container(
                              key: ValueKey(
                                  'routeAirportPoint-${entry.value.icao}'),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2)),
                            )),
                        Positioned(
                            left: entry.key == 0 ? 2 : 82,
                            top: 50,
                            width: 60,
                            child: _MapLabel(
                                text: entry.value.displayCode,
                                color: Theme.of(context).colorScheme.primary)),
                      ])),
                    ),
                ]),
              ],
              MarkerLayer(markers: [
                Marker(
                  key: const Key('trackingCenterMarker'),
                  point: LatLng(widget.controller.trackingCenter.latitude,
                      widget.controller.trackingCenter.longitude),
                  width: 44,
                  height: 44,
                  child: const _TrackingCenterMarker(),
                ),
              ]),
              MarkerLayer(
                markers: buildAircraftMapMarkers(
                  context: context,
                  aircraft: widget.controller.visibleAircraft,
                  selectedIcao24: widget.controller.selectedIcao24,
                  showLabels: _zoom >= 9,
                  onTap: _selectAircraft,
                ),
              ),
              RichAttributionWidget(
                popupBackgroundColor: Theme.of(context).colorScheme.surface,
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution(
                    widget.tileSource.attributionText,
                    onTap: () => unawaited(launchUrl(
                      widget.tileSource.attributionUri,
                      mode: LaunchMode.externalApplication,
                    )),
                  ),
                ],
              ),
            ],
          ),
          if (_showTrackHere) ...[
            const Center(
                child: IgnorePointer(child: Icon(Icons.add, size: 30))),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                  child: FilledButton.icon(
                key: const Key('trackMapHere'),
                onPressed: () =>
                    _setCenterFromMap(_mapController.camera.center),
                icon: const Icon(Icons.radar),
                label: const Text('Track here'),
              )),
            ),
          ],
          if (route != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: _showTrackHere ? 80 : 24,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: _RouteMapSummary(
                      key: ValueKey(route.identifier),
                      route: route,
                      count: widget.controller.visibleAircraft.length,
                      onClear: () => widget.controller.setDisplayFilter(null),
                    )),
              ),
            ),
          Positioned(
              top: 12,
              left: 12,
              child: ScreenAppearanceToggle(
                  screen: 'Map',
                  value: widget.controller.settings.effectiveMapAppearance,
                  onChanged: (value) => widget.controller.updateSettings(widget
                      .controller.settings
                      .copyWith(mapAppearance: value)))),
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              key: const Key('recenterMapButton'),
              tooltip: 'Re-centre on tracking location',
              onPressed: _recenter,
              child: const Icon(Icons.center_focus_strong),
            ),
          ),
          Positioned(
            top: 68,
            right: 12,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              child: ManualRefreshButton(
                  controller: widget.controller, surface: 'map'),
            ),
          ),
          if (widget.controller.isChoosingCenterOnMap)
            Positioned(
              top: 72,
              left: 12,
              right: 64,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Long-press the map to set the tracking centre',
                      textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectAircraft(TrackedAircraft aircraft) {
    widget.controller.select(aircraft.state.icao24);
    showAircraftDetail(context, aircraft, widget.controller);
  }

  void _recenter() {
    final center = widget.controller.trackingCenter;
    widget.viewportController.update(MapViewport(
      latitude: center.latitude,
      longitude: center.longitude,
      zoom: math.max(_zoom, 9),
    ));
  }

  void _setCenterFromMap(LatLng point) {
    setState(() => _showTrackHere = false);
    unawaited(widget.controller.setTrackingCenter(TrackingCenter(
      latitude: point.latitude,
      longitude: point.longitude,
      label:
          'Map point ${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)}',
      type: TrackingCenterType.map,
    )));
    widget.viewportController.update(MapViewport(
      latitude: point.latitude,
      longitude: point.longitude,
      zoom: _zoom,
    ));
  }
}

class _TrackingCenterMarker extends StatelessWidget {
  const _TrackingCenterMarker();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Active tracking centre',
        child: Center(
            child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface.withOpacity(.35),
            border: Border.all(
                color: Theme.of(context).colorScheme.secondary, width: 1.5),
          ),
          child: Icon(Icons.add_location,
              color: Theme.of(context).colorScheme.secondary, size: 12),
        )),
      );
}

List<Marker> buildAircraftMapMarkers({
  required BuildContext context,
  required List<TrackedAircraft> aircraft,
  required String? selectedIcao24,
  required bool showLabels,
  required ValueChanged<TrackedAircraft> onTap,
}) =>
    aircraft.map((item) {
      final selected = item.state.icao24 == selectedIcao24;
      return Marker(
        key: ValueKey('mapMarker-${item.state.icao24}'),
        point: LatLng(item.state.latitude, item.state.longitude),
        width: 168,
        height: 72,
        child: AircraftMapMarker(
          aircraft: item,
          selected: selected,
          showLabel: selected || showLabels,
          onTap: () => onTap(item),
        ),
      );
    }).toList(growable: false);

class AircraftMapMarker extends StatelessWidget {
  const AircraftMapMarker({
    required this.aircraft,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    super.key,
  });

  final TrackedAircraft aircraft;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final markerColor = selected
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: '${aircraft.primaryIdentifier} aircraft marker',
      child: Stack(children: [
        Positioned(
          left: 62,
          top: 14,
          width: 44,
          height: 44,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
                child: Transform.rotate(
              angle: aircraft.state.trackDegrees * math.pi / 180,
              child: Container(
                key: ValueKey('mapMarkerIcon-${aircraft.state.icao24}'),
                width: selected ? 26 : 22,
                height: selected ? 26 : 22,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(.25),
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: markerColor, width: 1.5)
                      : null,
                ),
                child: Icon(Icons.airplanemode_active,
                    color: markerColor.withOpacity(.9),
                    size: selected ? 19 : 17),
              ),
            )),
          ),
        ),
        if (showLabel)
          Positioned(
            left: 100,
            top: 8,
            width: 66,
            child: GestureDetector(
                onTap: onTap,
                child: _MapLabel(
                    text: aircraft.primaryIdentifier, color: markerColor)),
          ),
      ]),
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(.58),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

class _RouteMapSummary extends StatefulWidget {
  const _RouteMapSummary(
      {required this.route,
      required this.count,
      required this.onClear,
      super.key});
  final AircraftRoute route;
  final int count;
  final VoidCallback onClear;
  @override
  State<_RouteMapSummary> createState() => _RouteMapSummaryState();
}

class _RouteMapSummaryState extends State<_RouteMapSummary> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Material(
        key: const Key('routeMapSummary'),
        color: Theme.of(context).colorScheme.surface.withOpacity(.82),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
                child: InkWell(
              key: const Key('routeSummaryToggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                child: Row(children: [
                  const Icon(Icons.route, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text('${widget.route.label} · ${widget.count} in area',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const Text('Airport connection',
                            style: TextStyle(fontSize: 10)),
                      ])),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20),
                ]),
              ),
            )),
            IconButton(
                key: const Key('clearDisplayFilter'),
                tooltip: 'Clear route filter',
                onPressed: widget.onClear,
                icon: const Icon(Icons.close, size: 18)),
          ]),
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 100),
              child: SingleChildScrollView(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                    '${widget.count} matching aircraft in the current tracking area. '
                    'Airport connection only — not the actual flight track.',
                    key: const Key('routeSummaryDetails'),
                    style: const TextStyle(fontSize: 11)),
              )),
            ),
        ]),
      );
}
