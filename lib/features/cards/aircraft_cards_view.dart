import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/navigation/detail_navigation.dart';
import '../discovery/entity_detail_pages.dart';
import '../../domain/models/tracked_aircraft.dart';
import '../aircraft_detail/aircraft_detail_sheet.dart';

class AircraftCardsView extends StatelessWidget {
  const AircraftCardsView(
      {required this.controller, this.savedOnly = false, super.key});
  final AppController controller;
  final bool savedOnly;

  @override
  Widget build(BuildContext context) {
    final aircraft = controller.visibleAircraft
        .where((item) =>
            !savedOnly || controller.saved.contains(item.state.icao24))
        .toList();
    if (aircraft.isEmpty)
      return Center(
          child: Text(savedOnly
              ? 'No saved aircraft yet'
              : controller.displayFilter?.routeOrigin != null
                  ? 'No matching aircraft in the current tracking area.\nRoute information may be unavailable for some aircraft.'
                  : 'No aircraft match the filters'));
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 600
              ? 2
              : 1;
      return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 280,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12),
          itemCount: aircraft.length,
          itemBuilder: (context, index) =>
              _AircraftCard(aircraft: aircraft[index], controller: controller));
    });
  }
}

class _AircraftCard extends StatelessWidget {
  const _AircraftCard({required this.aircraft, required this.controller});
  final TrackedAircraft aircraft;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final state = aircraft.state;
    final route = aircraft.route;
    final origin = aircraft.flight?.origin ?? route?.origin;
    final destination = aircraft.flight?.destination ?? route?.destination;
    final connection = detailRoute(aircraft, controller);
    final navigation = DetailNavigation.maybeOf(context);
    final saved = controller.saved.contains(state.icao24);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: () {
            controller.select(state.icao24);
            showAircraftDetail(context, aircraft, controller);
          },
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(aircraft.primaryIdentifier,
                                style: Theme.of(context).textTheme.titleLarge),
                            if (aircraft.identity?.operatorName
                                case final name?)
                              InkWell(
                                  onTap: () => openOperatorDetails(
                                      context, name, controller),
                                  child: Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          decoration:
                                              TextDecoration.underline))),
                            InkWell(
                                onTap: () => openAircraftProfile(
                                    context, aircraft, controller),
                                child: Text(
                                    aircraft.identity?.model ??
                                        aircraft.identity?.typeCode ??
                                        'Aircraft details',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary))),
                          ])),
                      IconButton(
                          tooltip:
                              saved ? 'Remove saved aircraft' : 'Save aircraft',
                          onPressed: () => controller.toggleSaved(state.icao24),
                          icon: Icon(
                              saved ? Icons.bookmark : Icons.bookmark_border))
                    ]),
                    const Divider(),
                    Row(children: [
                      Expanded(
                          child: _Airport(
                              onTap: origin == null
                                  ? null
                                  : () => openAirportDetails(
                                      context, origin, controller),
                              code: origin?.displayCode ?? '—',
                              name: origin?.name ?? 'Origin unavailable')),
                      IconButton(
                          tooltip: 'Show route on map',
                          onPressed: connection != null &&
                                  connection.hasCoordinates &&
                                  navigation != null
                              ? () => navigation.route(connection)
                              : null,
                          icon: const Icon(Icons.route, size: 18)),
                      Expanded(
                          child: _Airport(
                              onTap: destination == null
                                  ? null
                                  : () => openAirportDetails(
                                      context, destination, controller),
                              code: destination?.displayCode ?? '—',
                              name: destination?.name ??
                                  'Destination unavailable',
                              alignEnd: true))
                    ]),
                    const Spacer(),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Metric(
                              label: 'ALTITUDE',
                              value: '${state.altitudeFeet.round()} ft'),
                          _Metric(
                              label: 'SPEED',
                              value: '${state.groundSpeedKnots.round()} kt'),
                          _Metric(
                              label: 'HEADING',
                              value: '${state.trackDegrees.round()}°'),
                          _Metric(
                              label: 'VERTICAL',
                              value: _vertical(state.verticalRateFeetPerMinute))
                        ]),
                    const SizedBox(height: 8),
                    Text(
                        '${aircraft.identity?.registration ?? state.icao24.toUpperCase()} · Callsign ${state.callsign.isEmpty ? 'unavailable' : state.callsign}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]))),
    );
  }

  String _vertical(double rate) => rate > 100
      ? '↑ ${rate.round()}'
      : rate < -100
          ? '↓ ${rate.abs().round()}'
          : '→ LEVEL';
}

class _Airport extends StatelessWidget {
  const _Airport(
      {required this.code,
      required this.name,
      this.alignEnd = false,
      this.onTap});
  final String code;
  final String name;
  final bool alignEnd;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(code,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(name,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall)
          ]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 8, letterSpacing: .7)),
        Text(value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
      ]);
}
