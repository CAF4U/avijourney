import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../alerts/alerts_page.dart';

import '../../app/app_controller.dart';
import '../../app/navigation/detail_navigation.dart';
import '../../domain/models/tracked_aircraft.dart';
import '../../domain/models/airport.dart';
import '../../domain/models/aircraft_route.dart';
import '../../app/mapping/map_tile_source.dart';
import '../../app/mapping/map_viewport_controller.dart';
import '../cards/aircraft_cards_view.dart';
import '../filters/settings_sheet.dart';
import '../filters/tracking_location_sheet.dart';
import '../map/aircraft_map_view.dart';
import '../radar/radar_view.dart';
import '../saved/followed_items_view.dart';
import '../search/universal_search_sheet.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.controller,
    required this.detailNavigation,
    required this.mapViewportController,
    required this.mapTileSource,
    this.showMapTiles = true,
    super.key,
  });

  final AppController controller;
  final DetailNavigationController detailNavigation;
  final MapViewportController mapViewportController;
  final MapTileSource mapTileSource;
  final bool showMapTiles;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _seenAlertRevision = 0;

  @override
  void initState() {
    super.initState();
    widget.detailNavigation.addListener(_openLinkedMap);
    _seenAlertRevision = widget.controller.alertRevision;
    widget.controller.addListener(_alertFeedback);
  }

  @override
  void dispose() {
    widget.detailNavigation.removeListener(_openLinkedMap);
    widget.controller.removeListener(_alertFeedback);
    super.dispose();
  }

  void _alertFeedback() {
    if (_seenAlertRevision == widget.controller.alertRevision) return;
    _seenAlertRevision = widget.controller.alertRevision;
    if (!widget.controller.isActive ||
        !widget.controller.settings.foregroundAlerts) return;
    if (widget.controller.settings.alertSound)
      SystemSound.play(SystemSoundType.click);
    if (widget.controller.settings.alertVibration) HapticFeedback.lightImpact();
  }

  void _openLinkedMap() {
    final target = widget.detailNavigation.target;
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (target is Airport) {
      _trackAirport(target);
    } else if (target is AircraftRoute) {
      _showRoute(target, true);
    } else if (target is TrackedAircraft) {
      widget.controller.select(target.state.icao24);
      _showSelectedAircraftOnMap();
    }
  }

  static const _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.radar), label: 'Radar'),
    NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
    NavigationDestination(
        icon: Icon(Icons.view_agenda_outlined), label: 'Cards'),
    NavigationDestination(
        icon: Icon(Icons.bookmark_border),
        selectedIcon: Icon(Icons.bookmark),
        label: 'Saved'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pages = <Widget>[
          RadarView(
            controller: widget.controller,
            onOpenTrackingLocation: _openTrackingLocation,
            tileSource: widget.mapTileSource,
            showTiles: widget.showMapTiles,
            onShowMap: () => setState(() => _index = 1),
          ),
          AircraftMapView(
            controller: widget.controller,
            viewportController: widget.mapViewportController,
            tileSource: widget.mapTileSource,
            showTiles: widget.showMapTiles,
          ),
          AircraftCardsView(controller: widget.controller),
          FollowedItemsView(controller: widget.controller),
        ];
        final wide = MediaQuery.sizeOf(context).width >= 700;
        final content = IndexedStack(index: _index, children: pages);
        return Scaffold(
          appBar: AppBar(
            title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CAF4U Aircraft Companion',
                      maxLines: 2,
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('V0.4.8 · DEVELOPMENT',
                      style: TextStyle(fontSize: 10, letterSpacing: 1.2)),
                ]),
            actions: [
              IconButton(
                  tooltip: 'Foreground alerts',
                  onPressed: () =>
                      openForegroundAlerts(context, widget.controller),
                  icon: const Icon(Icons.notifications_outlined)),
              IconButton(
                tooltip: 'Search aircraft, airlines and airports',
                onPressed: () => showUniversalSearch(
                  context,
                  widget.controller,
                  onShowOnMap: _showSelectedAircraftOnMap,
                  onTrackAirport: _trackAirport,
                  onShowRoute: _showRoute,
                ),
                icon: const Icon(Icons.search),
              ),
              _StatusBadge(
                  status: widget.controller.feedStatus,
                  feedName: widget.controller.feedName,
                  compact: MediaQuery.sizeOf(context).width < 600),
              if (MediaQuery.sizeOf(context).width >= 600)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                        child: Text(
                            '${widget.controller.visibleAircraft.length} visible'))),
              IconButton(
                  tooltip: 'Filters and settings',
                  onPressed: () => showSettingsSheet(
                        context,
                        widget.controller,
                        onChooseOnMap: _showMapForCenterSelection,
                      ),
                  icon: const Icon(Icons.tune)),
            ],
          ),
          bottomSheet: widget.controller.displayFilter == null ||
                  (_index == 1 && widget.controller.mapRoute != null)
              ? null
              : SafeArea(
                  child: Material(
                      child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      const Icon(Icons.filter_alt),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              '${widget.controller.displayFilter!.label} · ${widget.controller.visibleAircraft.length} matching in tracking area')),
                      TextButton(
                          key: const Key('clearDisplayFilter'),
                          onPressed: () =>
                              widget.controller.setDisplayFilter(null),
                          child: const Text('Clear filter')),
                    ]),
                  )),
                ),
          body: SafeArea(
            child: Column(children: [
              ForegroundAlertBanner(controller: widget.controller),
              Expanded(
                  child: wide
                      ? Row(children: [
                          NavigationRail(
                              selectedIndex: _index,
                              onDestinationSelected: (value) =>
                                  setState(() => _index = value),
                              labelType: NavigationRailLabelType.all,
                              destinations: _destinations
                                  .map((item) => NavigationRailDestination(
                                      icon: item.icon,
                                      selectedIcon: item.selectedIcon,
                                      label: Text(item.label)))
                                  .toList()),
                          const VerticalDivider(width: 1),
                          Expanded(child: content),
                        ])
                      : content),
            ]),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  destinations: _destinations),
        );
      },
    );
  }

  void _showRoute(AircraftRoute route, bool onMap) {
    widget.controller.showRoute(route, onMap: onMap);
    setState(() => _index = onMap ? 1 : 2);
    if (onMap && route.hasCoordinates) {
      widget.mapViewportController.update(MapViewport(
          latitude: route.origin.latitude!,
          longitude: route.origin.longitude!,
          zoom: 3,
          route: route));
    }
  }

  void _showSelectedAircraftOnMap() {
    final selected = [
      ...widget.controller.mapAircraft,
      ...widget.controller.aircraft
    ]
        .where((item) => item.state.icao24 == widget.controller.selectedIcao24)
        .firstOrNull;
    if (selected != null) {
      if (!identical(widget.controller.incomingMapTarget?.aircraft, selected)) {
        widget.controller.setDisplayFilter(null);
      }
      widget.mapViewportController.update(MapViewport(
          latitude: selected.state.latitude,
          longitude: selected.state.longitude,
          zoom: 10,
          route: widget.controller.incomingMapTarget == null
              ? null
              : (selected.route?.origin != null &&
                      selected.route?.destination != null
                  ? AircraftRoute(
                      origin: selected.route!.origin!,
                      destination: selected.route!.destination!)
                  : null)));
    }
    setState(() => _index = 1);
  }

  void _trackAirport(Airport airport) {
    widget.controller.setDisplayFilter(null);
    // chooseAirport updates the tracking centre synchronously before acquisition.
    unawaited(widget.controller.chooseAirport(airport));
    setState(() => _index = 1);
  }

  void _showMapForCenterSelection() => setState(() => _index = 1);

  void _openTrackingLocation() => showTrackingLocationSheet(
        context,
        widget.controller,
        onChooseOnMap: _showMapForCenterSelection,
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(
      {required this.status, required this.feedName, this.compact = false});
  final bool compact;
  final FeedStatus status;
  final String feedName;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      FeedStatus.connecting => 'CONNECTING',
      FeedStatus.live => 'LIVE · ${feedName.toUpperCase()}',
      FeedStatus.cached => 'CACHED',
      FeedStatus.offline => 'OFFLINE',
      FeedStatus.rateLimited => 'RATE LIMITED',
      FeedStatus.error => 'FEED ERROR',
    };
    return Center(
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                border:
                    Border.all(color: Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(20)),
            child: Text(compact ? status.name.toUpperCase() : label,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold))));
  }
}
