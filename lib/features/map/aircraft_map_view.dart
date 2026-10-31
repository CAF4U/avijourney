import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
      padding: const EdgeInsets.fromLTRB(48, 80, 48, 140),
      maxZoom: 8);

  @override
  void dispose() {
    widget.viewportController.removeListener(_moveToExternalViewport);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              onPositionChanged: (camera, _) {
                widget.viewportController.updateFromMap(MapViewport(
                  latitude: camera.center.latitude,
                  longitude: camera.center.longitude,
                  zoom: camera.zoom,
                ));
                if ((_zoom >= 9) != (camera.zoom >= 9)) {
                  setState(() => _zoom = camera.zoom);
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
                  for (final airport in [route.origin, route.destination])
                    Marker(
                        point: LatLng(airport.latitude!, airport.longitude!),
                        width: 110,
                        height: 54,
                        child: Card(
                            child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_airport,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      Text(airport.displayCode,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ])))),
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
          if (route != null)
            Positioned(
                left: 12,
                right: 12,
                bottom: 80,
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                            '${route.label} · ${widget.controller.visibleAircraft.length} matching aircraft in current tracking area.\nAirport connection only — not the actual flight track.')))),
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
          if (widget.controller.isChoosingCenterOnMap)
            Positioned(
              top: 12,
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
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
                color: Theme.of(context).colorScheme.secondary, width: 3),
          ),
          child: Icon(Icons.add_location,
              color: Theme.of(context).colorScheme.secondary, size: 24),
        ),
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
        width: selected || showLabels ? 112 : 48,
        height: selected || showLabels ? 62 : 48,
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: aircraft.state.trackDegrees * math.pi / 180,
              child: Container(
                key: ValueKey('mapMarkerIcon-${aircraft.state.icao24}'),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: markerColor,
                    width: selected ? 3 : 1.5,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: markerColor, blurRadius: 9)]
                      : null,
                ),
                child: Icon(Icons.navigation, color: markerColor, size: 18),
              ),
            ),
            if (showLabel)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  aircraft.primaryIdentifier,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: markerColor,
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
