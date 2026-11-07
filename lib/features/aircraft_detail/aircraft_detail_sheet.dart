import 'package:flutter/material.dart';
import '../aircraft_detail/incoming_aircraft_sheet.dart';

import '../../app/app_controller.dart';
import '../../core/widgets/manual_refresh_button.dart';
import '../../app/alerts/foreground_alert_engine.dart';
import '../../app/navigation/detail_navigation.dart';
import '../discovery/detail_widgets.dart';
import '../discovery/entity_detail_pages.dart';
import '../../domain/models/tracked_aircraft.dart';

Future<void> showAircraftDetail(BuildContext context, TrackedAircraft aircraft,
        AppController controller) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => FractionallySizedBox(
            heightFactor: .88,
            child:
                _AircraftDetail(aircraft: aircraft, controller: controller)));

class _AircraftDetail extends StatefulWidget {
  const _AircraftDetail({required this.aircraft, required this.controller});
  final TrackedAircraft aircraft;
  final AppController controller;

  @override
  State<_AircraftDetail> createState() => _AircraftDetailState();
}

class _AircraftDetailState extends State<_AircraftDetail> {
  AppController get controller => widget.controller;
  TrackedAircraft get aircraft => widget.aircraft;
  late TrackedAircraft _lastKnown = widget.aircraft;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _buildDetails(context),
      );

  Widget _buildDetails(BuildContext context) {
    final latest = controller.mapAircraft
        .where((item) => item.state.icao24 == aircraft.state.icao24)
        .firstOrNull;
    if (latest != null) _lastKnown = latest;
    final current = _lastKnown;
    final state = current.state;
    final identity = current.identity;
    final route = current.route;
    final airline = controller.flightAirline(current);
    final origin = current.flight?.origin ?? route?.origin;
    final destination = current.flight?.destination ?? route?.destination;
    final connection = detailRoute(current, controller);
    final navigation = DetailNavigation.maybeOf(context);
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        Expanded(
            child: Text(current.primaryIdentifier,
                style: Theme.of(context).textTheme.headlineMedium)),
        IconButton(
            onPressed: () => controller.toggleSaved(state.icao24),
            icon: Icon(controller.saved.contains(state.icao24)
                ? Icons.bookmark
                : Icons.bookmark_border)),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close))
      ]),
      Text(state.callsign.isEmpty
          ? 'No callsign available'
          : 'Callsign ${state.callsign}'),
      OutlinedButton.icon(
          key: const Key('findIncomingAircraft'),
          onPressed: () => showIncomingAircraft(context, controller, current,
              initialAirport: origin),
          icon: const Icon(Icons.flight_land),
          label: const Text('Find incoming aircraft')),
      const SizedBox(height: 20),
      DetailSection(title: 'FLIGHT AIRLINE', actions: {
        if (airline.airline != null)
          'Airline': () => openOperatorDetails(
              context, airline.name, controller,
              asAirline: true, airlineReference: airline.airline),
      }, rows: {
        'Airline': airline.name,
        'Airline basis': airline.basis
      }),
      DetailSection(
          title: 'AIRCRAFT',
          onTitleTap: () => openAircraftProfile(context, current, controller),
          actions: {
            if (identity?.operatorName case final name?)
              'Operator': () => openOperatorDetails(context, name, controller),
            if (identity != null)
              'Model / type': () =>
                  openAircraftProfile(context, current, controller),
            'Registration': () =>
                openAircraftProfile(context, current, controller),
          },
          rows: {
            'Operator': identity?.operatorName ?? 'Unavailable',
            'Model / type':
                identity?.model ?? identity?.typeCode ?? 'Unavailable',
            'Registration': identity?.registration ?? 'Unavailable',
            'ICAO24': state.icao24.toUpperCase()
          }),
      DetailSection(
          title: 'ROUTE',
          onTitleTap: connection != null &&
                  connection.hasCoordinates &&
                  navigation != null
              ? () => navigation.route(connection)
              : null,
          actions: {
            if (origin != null)
              'Origin': () => openAirportDetails(context, origin, controller),
            if (destination != null)
              'Destination': () =>
                  openAirportDetails(context, destination, controller),
          },
          rows: {
            'Origin': origin == null
                ? 'Unavailable'
                : '${origin.displayCode} · ${origin.name}',
            'Destination': destination == null
                ? 'Unavailable'
                : '${destination.displayCode} · ${destination.name}',
            'Provenance': route?.source ?? 'No verified route source'
          }),
      DetailSection(
          title: 'LIVE METRICS',
          trailing:
              ManualRefreshButton(controller: controller, surface: 'metrics'),
          rows: {
            'Feed': latest == null
                ? 'No longer in current snapshot · last known data'
                : controller.feedStatus.name,
            'Altitude': '${state.altitudeFeet.round()} ft',
            'Ground speed': '${state.groundSpeedKnots.round()} kt',
            'Heading': '${state.trackDegrees.round()}°',
            'Vertical rate':
                '${state.verticalRateFeetPerMinute.round()} ft/min',
            'Squawk': state.squawk ?? 'Unavailable',
            'Movement': estimatedMovement(state),
            'Position timestamp':
                state.positionTime?.toLocal().toString() ?? 'Unavailable',
            'ACARS / OOOI':
                'Not connected; OUT/IN cannot be established from speed or altitude',
            'Position':
                '${state.latitude.toStringAsFixed(4)}, ${state.longitude.toStringAsFixed(4)}'
          }),
      DetailSection(title: 'OBSERVED HISTORY', rows: {
        'Trail points': '${current.trail.length}',
        'Latest observation': state.observedAt.toLocal().toString()
      }),
    ]);
  }
}
