import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/navigation/detail_navigation.dart';
import '../discovery/detail_widgets.dart';
import '../discovery/entity_detail_pages.dart';
import '../../domain/models/followed_item.dart';
import '../../domain/models/tracked_aircraft.dart';

Future<void> showFlightDetail(
  BuildContext context,
  TrackedAircraft aircraft,
  AppController controller, {
  required VoidCallback onShowOnMap,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .88,
        child: FlightDetailView(
          aircraft: aircraft,
          controller: controller,
          onShowOnMap: onShowOnMap,
        ),
      ),
    );

class FlightDetailView extends StatelessWidget {
  const FlightDetailView({
    required this.aircraft,
    required this.controller,
    required this.onShowOnMap,
    super.key,
  });

  final TrackedAircraft aircraft;
  final AppController controller;
  final VoidCallback onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final flight = aircraft.flight;
    final route = aircraft.route;
    final airline = controller.flightAirline(aircraft);
    final connection = detailRoute(aircraft, controller);
    final navigation = DetailNavigation.maybeOf(context);
    final origin = flight?.origin ?? route?.origin;
    final destination = flight?.destination ?? route?.destination;
    final item = FollowedItem(
      type: FollowedItemType.flight,
      identifier: flight?.primaryIdentifier ?? aircraft.state.callsign,
      label: flight?.primaryIdentifier ?? aircraft.state.callsign,
      subtitle: origin != null && destination != null
          ? '${origin.displayCode} → ${destination.displayCode}'
          : null,
    );
    String time(DateTime? value) =>
        value?.toLocal().toString() ?? 'Unavailable';
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        Expanded(
          child: Text(flight?.primaryIdentifier ?? aircraft.state.callsign,
              style: Theme.of(context).textTheme.headlineMedium),
        ),
        IconButton(
          tooltip: controller.isFollowing(item)
              ? 'Unfollow flight'
              : 'Follow flight',
          onPressed: () => controller.toggleFollowed(item),
          icon: Icon(controller.isFollowing(item)
              ? Icons.notifications_active
              : Icons.notifications_none),
        ),
        IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.close)),
      ]),
      Text(flight?.isCommercialIdentityVerified == true
          ? 'VERIFIED COMMERCIAL FLIGHT'
          : 'OPERATIONAL CALLSIGN · COMMERCIAL NUMBER UNRESOLVED'),
      const SizedBox(height: 16),
      DetailSection(title: 'IDENTITY', actions: {
        if (airline.airline != null)
          'Airline': () => openOperatorDetails(
              context, airline.name, controller,
              asAirline: true, airlineReference: airline.airline),
        if (aircraft.identity?.operatorName case final name?)
          'Operator': () => openOperatorDetails(context, name, controller)
      }, rows: {
        'Commercial number': flight?.isCommercialIdentityVerified == true
            ? flight!.commercialFlightNumber!
            : 'Unresolved',
        'Airline': airline.name,
        'Airline basis': airline.basis,
        'Operator': aircraft.identity?.operatorName ?? 'Unavailable',
        'Callsign': flight?.operationalCallsign ?? aircraft.state.callsign,
        'Status': flight?.status ?? 'Unavailable',
      }),
      DetailSection(
          title: 'ROUTE & SCHEDULE',
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
                  openAirportDetails(context, destination, controller)
          },
          rows: {
            'Origin': origin == null
                ? 'Unavailable'
                : '${origin.displayCode} · ${origin.name}',
            'Destination': destination == null
                ? 'Unavailable'
                : '${destination.displayCode} · ${destination.name}',
            'Scheduled departure': time(flight?.scheduledDeparture),
            'Scheduled arrival': time(flight?.scheduledArrival),
            'Estimated departure': time(flight?.estimatedDeparture),
            'Estimated arrival': time(flight?.estimatedArrival),
            'Actual departure': time(flight?.actualDeparture),
            'Actual arrival': time(flight?.actualArrival),
          }),
      DetailSection(
          title: 'AIRCRAFT & PROVENANCE',
          onTitleTap: () => openAircraftProfile(context, aircraft, controller),
          actions: {
            'Type': () => openAircraftProfile(context, aircraft, controller),
            'Registration': () =>
                openAircraftProfile(context, aircraft, controller)
          },
          rows: {
            'Registration': flight?.aircraftRegistration ??
                aircraft.identity?.registration ??
                'Unavailable',
            'Type': flight?.aircraftType ??
                aircraft.identity?.model ??
                aircraft.identity?.typeCode ??
                'Unavailable',
            'ICAO24': aircraft.state.icao24.toUpperCase(),
            'Source':
                flight?.source ?? route?.source ?? 'No verified flight source',
          }),
      FilledButton.icon(
        key: const Key('showAircraftOnMap'),
        onPressed: () {
          controller.select(aircraft.state.icao24);
          Navigator.maybePop(context);
          onShowOnMap();
        },
        icon: const Icon(Icons.map_outlined),
        label: const Text('Show aircraft on map'),
      ),
    ]);
  }
}
