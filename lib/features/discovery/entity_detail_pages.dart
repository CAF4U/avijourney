import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../app/alerts/foreground_alert_engine.dart';
import '../../app/discovery/airport_traffic.dart';
import '../../app/navigation/detail_navigation.dart';
import '../../domain/models/airport.dart';
import '../../domain/models/airline.dart';
import '../../domain/models/aircraft_filter.dart';
import '../../domain/models/aircraft_route.dart';
import '../../domain/models/followed_item.dart';
import '../../domain/models/tracked_aircraft.dart';
import '../aircraft_detail/aircraft_detail_sheet.dart';
import '../weather/airport_weather_page.dart';
import 'detail_widgets.dart';

void openAirportDetails(
        BuildContext context, Airport airport, AppController controller) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AirportDetailPage(
            airport: controller.airportDetails(airport),
            controller: controller)));
void openOperatorDetails(
        BuildContext context, String name, AppController controller,
        {bool asAirline = false, Airline? airlineReference}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OperatorDetailPage(
            operator: airlineReference ?? controller.operatorDetails(name),
            asAirline: asAirline,
            controller: controller)));
void openAircraftProfile(BuildContext context, TrackedAircraft aircraft,
        AppController controller) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            AircraftProfilePage(aircraft: aircraft, controller: controller)));

AircraftRoute? detailRoute(TrackedAircraft aircraft, AppController controller) {
  final origin = aircraft.flight?.origin ?? aircraft.route?.origin;
  final destination =
      aircraft.flight?.destination ?? aircraft.route?.destination;
  return origin == null || destination == null
      ? null
      : AircraftRoute(
          origin: controller.airportDetails(origin),
          destination: controller.airportDetails(destination));
}

class AirportDetailPage extends StatelessWidget {
  const AirportDetailPage(
      {required this.airport, required this.controller, super.key});
  final Airport airport;
  final AppController controller;
  void _show(BuildContext context, AirportTraffic traffic,
          {bool find = false}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => AirportTrafficPage(
              airport: airport,
              controller: controller,
              traffic: traffic,
              focusSearch: find)));
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final navigation = DetailNavigation.maybeOf(context);
        final canMap = airport.latitude != null &&
            airport.longitude != null &&
            navigation != null;
        final saved = FollowedItem(
            type: FollowedItemType.airport,
            identifier: airport.icao,
            label: airport.name);
        return Scaffold(
            key: const Key('airportDetailPage'),
            appBar: AppBar(title: Text(airport.displayCode), actions: [
              IconButton(
                  tooltip: controller.isFollowing(saved)
                      ? 'Unfollow airport'
                      : 'Follow airport',
                  onPressed: () => controller.toggleFollowed(saved),
                  icon: Icon(controller.isFollowing(saved)
                      ? Icons.bookmark
                      : Icons.bookmark_border)),
            ]),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              Text(airport.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              Text('${airport.iata ?? "IATA unavailable"} / ${airport.icao}'),
              const SizedBox(height: 12),
              FilledButton.icon(
                  key: const Key('airportShowMap'),
                  onPressed: canMap ? () => navigation.airport(airport) : null,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Show on map / scan around airport')),
              ExpansionTile(
                  key: const Key('airportGeneralInfo'),
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  title: const Text('General airport information'),
                  children: [
                    DetailSection(title: 'AIRPORT INFORMATION', rows: {
                      'City': airport.city ?? 'Unavailable',
                      'Country': airport.country ?? 'Unavailable',
                      'IATA': airport.iata ?? 'Unavailable',
                      'ICAO': airport.icao,
                      'Airport type':
                          airport.type?.replaceAll('_', ' ') ?? 'Unavailable',
                      'Latitude':
                          airport.latitude?.toStringAsFixed(5) ?? 'Unavailable',
                      'Longitude': airport.longitude?.toStringAsFixed(5) ??
                          'Unavailable',
                      'Reference':
                          'Bundled airport catalogue / supplied route data',
                    })
                  ]),
              _action(
                  'airportArrivals',
                  Icons.flight_land,
                  'Arrival board · observed aircraft',
                  () => _show(context, AirportTraffic.arrivals)),
              _action(
                  'airportDepartures',
                  Icons.flight_takeoff,
                  'Departure board · observed aircraft',
                  () => _show(context, AirportTraffic.departures)),
              _action(
                  'airportGround',
                  Icons.airplanemode_active,
                  'Aircraft on ground near airport',
                  airport.latitude == null || airport.longitude == null
                      ? null
                      : () => _show(context, AirportTraffic.ground)),
              _action(
                  'findArrivingFlight',
                  Icons.search,
                  'Find arriving flight',
                  () => _show(context, AirportTraffic.arrivals, find: true)),
              _action(
                  'findDepartingFlight',
                  Icons.search,
                  'Find departing flight',
                  () => _show(context, AirportTraffic.departures, find: true)),
              _action(
                  'airportWeather',
                  Icons.cloud_outlined,
                  'Airport weather · METAR / TAF',
                  () => openAirportWeather(context, airport, controller)),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      'Scheduled arrival/departure times, gates and airport-wide flight status are not supplied by the current providers. These lists use acquired aircraft with known route information, not a complete airport schedule.')),
            ]));
      });
  Widget _action(
          String key, IconData icon, String title, VoidCallback? action) =>
      ListTile(
          key: Key(key),
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: action,
          enabled: action != null);
}

class AirportTrafficPage extends StatefulWidget {
  const AirportTrafficPage(
      {required this.airport,
      required this.controller,
      required this.traffic,
      this.focusSearch = false,
      super.key});
  final Airport airport;
  final AppController controller;
  final AirportTraffic traffic;
  final bool focusSearch;
  @override
  State<AirportTrafficPage> createState() => _AirportTrafficPageState();
}

class _AirportTrafficPageState extends State<AirportTrafficPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final traffic = widget.traffic;
        final aircraft = controller.aircraft
            .where((a) =>
                matchesAirportTraffic(a, widget.airport, traffic) &&
                [
                  a.primaryIdentifier,
                  a.state.callsign,
                  a.identity?.registration,
                  a.identity?.operatorName
                ]
                    .whereType<String>()
                    .join(' ')
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
            .toList();
        final heading = switch (traffic) {
          AirportTraffic.arrivals => 'OBSERVED ARRIVALS',
          AirportTraffic.departures => 'OBSERVED DEPARTURES',
          AirportTraffic.ground => 'OBSERVED ON GROUND'
        };
        return Scaffold(
            key: const Key('airportTrafficPage'),
            appBar: AppBar(title: Text(widget.airport.displayCode)),
            body: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heading,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                          'Feed: ${controller.feedStatus.name} · current tracking area: ${controller.trackingCenter.label}'),
                      const Text(
                          'Observed aircraft only, not a complete scheduled airport board.'),
                      if (traffic == AirportTraffic.ground)
                        const Text(
                            'Reported on ground and within 3 NM of the airport reference point; this may include neighbouring airfields.'),
                      TextField(
                          key: const Key('airportFlightSearch'),
                          autofocus: widget.focusSearch,
                          onChanged: (s) => setState(() => _query = s),
                          decoration: const InputDecoration(
                              labelText:
                                  'Find callsign, registration or operator',
                              prefixIcon: Icon(Icons.search))),
                      Text('${aircraft.length} matching observed aircraft'),
                      Expanded(
                          child: aircraft.isEmpty
                              ? const SingleChildScrollView(
                                  child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16),
                                      child: Text(
                                          'No matching aircraft in acquired data. This does not mean there are no flights. Scan around this airport to acquire local positions.')))
                              : ListView.builder(
                                  itemCount: aircraft.length,
                                  itemBuilder: (context, index) {
                                    final a = aircraft[index];
                                    return ListTile(
                                        key: Key(
                                            'airportAircraft-${a.state.icao24}'),
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(a.primaryIdentifier),
                                        subtitle: Text(
                                            '${a.identity?.registration ?? a.state.icao24} · observed ${a.state.observedAt.toLocal()}'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () => showAircraftDetail(
                                            context, a, controller));
                                  })),
                    ])));
      });
}

class OperatorDetailPage extends StatelessWidget {
  const OperatorDetailPage(
      {required this.operator,
      required this.controller,
      this.asAirline = false,
      super.key});
  final Airline operator;
  final bool asAirline;
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final matches = controller.aircraft
            .where((a) =>
                AircraftFilter(label: operator.name, airline: operator)
                    .matches(a, matchesQuery: false))
            .toList();
        final item = FollowedItem(
            type: FollowedItemType.airline,
            identifier: operator.identifier,
            label: operator.name);
        return Scaffold(
            key: const Key('operatorDetailPage'),
            appBar: AppBar(
                title: Text(asAirline
                    ? 'Airline details'
                    : 'Aircraft operator details'),
                actions: [
                  IconButton(
                      tooltip: controller.isFollowing(item)
                          ? 'Unfollow operator'
                          : 'Follow operator',
                      onPressed: () => controller.toggleFollowed(item),
                      icon: Icon(controller.isFollowing(item)
                          ? Icons.bookmark
                          : Icons.bookmark_border))
                ]),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              Text(operator.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              DetailSection(
                  title: asAirline
                      ? 'AIRLINE INFORMATION'
                      : 'OPERATOR INFORMATION',
                  rows: {
                    'Name': operator.name,
                    'IATA': operator.iataCode ?? 'Unavailable',
                    'ICAO': operator.icaoCode ?? 'Unavailable',
                    'Country': operator.country ?? 'Unavailable',
                    'Reference date': operator.referenceDate?.isNotEmpty == true
                        ? operator.referenceDate!
                        : 'Unavailable',
                    'Source': operator.source?.isNotEmpty == true
                        ? operator.source!
                        : operator.icaoCode == null && operator.iataCode == null
                            ? 'Aircraft operator / owner enrichment; no exact airline catalogue match'
                            : 'Bundled airline reference catalogue'
                  }),
              const Text(
                  'An aircraft operator or registered owner is not necessarily the passenger-facing airline. Reference catalogue records do not establish current operating status.'),
              const SizedBox(height: 16),
              Text('OBSERVED AIRCRAFT · ${matches.length}',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                  'Matching known operator names or airline codes in acquired data. Feed: ${controller.feedStatus.name}.'),
              if (matches.isEmpty)
                const Text(
                    'No matching aircraft in the current tracking area.'),
              for (final a in matches)
                ListTile(
                    title: Text(a.primaryIdentifier),
                    subtitle: Text(a.identity?.registration ?? a.state.icao24),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showAircraftDetail(context, a, controller)),
              const Text(
                  'Full fleet size, headquarters, website and operating status are unavailable from the current reference data.'),
            ]));
      });
}

class AircraftProfilePage extends StatelessWidget {
  const AircraftProfilePage(
      {required this.aircraft, required this.controller, super.key});
  final TrackedAircraft aircraft;
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final identity = aircraft.identity;
    final airline = controller.flightAirline(aircraft);
    final navigation = DetailNavigation.maybeOf(context);
    final route = detailRoute(aircraft, controller);
    return Scaffold(
        key: const Key('aircraftProfilePage'),
        appBar: AppBar(title: const Text('Aircraft details')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(identity?.registration ?? aircraft.state.icao24.toUpperCase(),
              style: Theme.of(context).textTheme.headlineMedium),
          DetailSection(title: 'PHYSICAL AIRCRAFT', rows: {
            'Registration': identity?.registration ?? 'Unavailable',
            'ICAO24': aircraft.state.icao24.toUpperCase(),
            'Model / type':
                identity?.model ?? identity?.typeCode ?? 'Unavailable',
            'Type code': identity?.typeCode ?? 'Unavailable',
            'Operator': identity?.operatorName ?? 'Unavailable'
          }, actions: {
            if (identity?.operatorName case final name?)
              'Operator': () => openOperatorDetails(context, name, controller)
          }),
          const Text(
              'Manufacturer, age, delivery date and aircraft photographs are unavailable from the current identity data.'),
          const SizedBox(height: 16),
          DetailSection(title: 'OBSERVED OPERATION', actions: {
            if (airline.airline != null)
              'Airline': () => openOperatorDetails(
                  context, airline.name, controller,
                  asAirline: true, airlineReference: airline.airline),
          }, rows: {
            'Airline': airline.name,
            'Airline basis': airline.basis,
            'Identifier': aircraft.primaryIdentifier,
            'Callsign': aircraft.state.callsign,
            'Movement': estimatedMovement(aircraft.state),
            'Altitude': '${aircraft.state.altitudeFeet.round()} ft',
            'Ground speed': '${aircraft.state.groundSpeedKnots.round()} kt',
            'Observed': aircraft.state.observedAt.toLocal().toString()
          }),
          FilledButton.icon(
              key: const Key('profileShowMap'),
              onPressed: navigation == null
                  ? null
                  : () => navigation.aircraft(aircraft),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Show aircraft on map')),
          if (route != null)
            OutlinedButton.icon(
                onPressed: route.hasCoordinates && navigation != null
                    ? () => navigation.route(route)
                    : null,
                icon: const Icon(Icons.route),
                label: Text('Show ${route.label} route')),
        ]));
  }
}
