import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/search/universal_search_service.dart';
import '../../domain/models/airline.dart';
import '../../domain/models/aircraft_filter.dart';
import '../../domain/models/aircraft_route.dart';
import '../../domain/models/airport.dart';
import '../../domain/models/followed_item.dart';
import '../../domain/models/search_result.dart';
import '../../domain/models/tracked_aircraft.dart';
import '../aircraft_detail/aircraft_detail_sheet.dart';
import '../flight_detail/flight_detail_sheet.dart';

Future<void> showUniversalSearch(
  BuildContext context,
  AppController controller, {
  required VoidCallback onShowOnMap,
  required ValueChanged<Airport> onTrackAirport,
  required void Function(AircraftRoute, bool) onShowRoute,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .92,
        child: _UniversalSearchSheet(
          controller: controller,
          onShowOnMap: onShowOnMap,
          onTrackAirport: onTrackAirport,
          onShowRoute: onShowRoute,
        ),
      ),
    );

class _UniversalSearchSheet extends StatefulWidget {
  const _UniversalSearchSheet(
      {required this.controller,
      required this.onShowOnMap,
      required this.onTrackAirport,
      required this.onShowRoute});
  final AppController controller;
  final VoidCallback onShowOnMap;
  final ValueChanged<Airport> onTrackAirport;
  final void Function(AircraftRoute, bool) onShowRoute;

  @override
  State<_UniversalSearchSheet> createState() => _UniversalSearchSheetState();
}

class _UniversalSearchSheetState extends State<_UniversalSearchSheet> {
  static const _examples = <String>[
    'BAW12',
    'G-EUYA',
    'British Airways',
    'LHR → LAX',
    'JFK',
    'A380 Emirates',
  ];
  final _query = TextEditingController();
  List<SearchResult> _results = const [];
  bool _hasSubmitted = false;
  String _submittedQuery = "";

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final query = value ?? _query.text;
    FocusScope.of(context).unfocus();
    _query.text = query;
    _query.selection = TextSelection.collapsed(offset: query.length);
    setState(() {
      _hasSubmitted = true;
      _submittedQuery = query.trim();
      _results = widget.controller.search(query);
    });
    final routes =
        _results.where((r) => r.type == SearchResultType.route).toList();
    if (UniversalSearchService.routeCodes(query) != null &&
        routes.length == 1) {
      _showResultActions(routes.single);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <SearchResultType, List<SearchResult>>{};
    for (final result in _results) {
      grouped.putIfAbsent(result.type, () => []).add(result);
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              key: const Key('universalSearchField'),
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: 'Flight, aircraft, airline, route or airport',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: _submit,
                    icon: const Icon(Icons.arrow_forward)),
              ),
            ),
          ),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
        ]),
      ),
      if (_hasSubmitted && _submittedQuery.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.icon(
            key: const Key('filterSearchResults'),
            onPressed: () => _applyFilter(AircraftFilter(
                label: 'Search: $_submittedQuery', query: _submittedQuery)),
            icon: const Icon(Icons.filter_alt),
            label: const Text('Filter radar / map by this search'),
          ),
        ),
      Expanded(
        child: _results.isEmpty
            ? _SearchGuidance(
                hasSubmitted: _hasSubmitted,
                examples: _examples,
                onExampleSelected: _submit,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final type in SearchResultType.values)
                    if (grouped[type]?.isNotEmpty == true) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 4),
                        child: Text(_heading(type),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                      ),
                      ...grouped[type]!.map(_tile),
                    ],
                  const _CatalogAttribution(),
                ],
              ),
      ),
    ]);
  }

  Widget _tile(SearchResult result) {
    final followed = _followed(result);
    return Card(
      child: ListTile(
        title: Text(result.title),
        subtitle: Text('${result.subtitle}\n${result.matchReason}'),
        isThreeLine: true,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              tooltip: 'Filter radar / map',
              icon: const Icon(Icons.filter_alt_outlined),
              onPressed: () => _showResultActions(result)),
          IconButton(
            tooltip: followed != null && widget.controller.isFollowing(followed)
                ? 'Unfollow'
                : 'Follow',
            onPressed: followed == null
                ? null
                : () =>
                    setState(() => widget.controller.toggleFollowed(followed)),
            icon: Icon(
                followed != null && widget.controller.isFollowing(followed)
                    ? Icons.bookmark
                    : Icons.bookmark_border),
          ),
        ]),
        onTap: () {
          final tracked = result.value;
          if (tracked is TrackedAircraft &&
              result.type != SearchResultType.route) {
            if (result.type == SearchResultType.flight) {
              showFlightDetail(context, tracked, widget.controller,
                  onShowOnMap: () {
                Navigator.pop(context);
                widget.onShowOnMap();
              });
            } else {
              widget.controller.select(tracked.state.icao24);
              showAircraftDetail(context, tracked, widget.controller);
            }
          } else {
            _showResultActions(result);
          }
        },
      ),
    );
  }

  void _applyFilter(AircraftFilter filter) {
    widget.controller.setDisplayFilter(filter);
    Navigator.pop(context);
  }

  void _showResultActions(SearchResult result) {
    final value = result.value;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (detailContext) {
        void filter(AircraftFilter selected) {
          Navigator.pop(detailContext);
          _applyFilter(selected);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(result.title,
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: 'Close details',
                      onPressed: () => Navigator.pop(detailContext),
                      icon: const Icon(Icons.close)),
                ]),
                Text(result.subtitle),
                const SizedBox(height: 12),
                if (value is AircraftRoute) ...[
                  Text('Choose how to view this route',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      '${widget.controller.aircraft.where((a) => AircraftFilter(label: "route", routeOrigin: value.origin, routeDestination: value.destination).matches(a, matchesQuery: false)).length} known aircraft in the current tracking area. Other active filters still apply.'),
                  const Text(
                      'Airport connection only, not a confirmed scheduled service. No worldwide live-aircraft search is available.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                      key: const Key('routeAircraftList'),
                      onPressed: () {
                        Navigator.pop(detailContext);
                        Navigator.pop(context);
                        widget.onShowRoute(value, false);
                      },
                      icon: const Icon(Icons.view_list),
                      label: const Text('List aircraft on this route')),
                  OutlinedButton.icon(
                      key: const Key('routeAircraftMap'),
                      onPressed: !value.hasCoordinates
                          ? null
                          : () {
                              Navigator.pop(detailContext);
                              Navigator.pop(context);
                              widget.onShowRoute(value, true);
                            },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Show route and aircraft on map')),
                ] else if (value is Airport) ...[
                  Text(
                      'ICAO: ${value.icao} · IATA: ${value.iata ?? "Unavailable"}'),
                  Text(
                      'Coordinates: ${value.latitude ?? "Unavailable"}, ${value.longitude ?? "Unavailable"}'),
                  const Text(
                      'Airport reference data · OurAirports. Route filters use known routes in the current tracking area.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('trackSelectedAirport'),
                    onPressed: value.latitude == null || value.longitude == null
                        ? null
                        : () {
                            Navigator.pop(detailContext);
                            Navigator.pop(context);
                            widget.onTrackAirport(value);
                          },
                    icon: const Icon(Icons.radar),
                    label: const Text('Track around this airport'),
                  ),
                  for (final direction in AirportDirection.values)
                    OutlinedButton(
                        onPressed: () => filter(AircraftFilter(
                            label:
                                '${_directionLabel(direction)} ${value.displayCode}',
                            airport: value,
                            direction: direction)),
                        child:
                            Text('${_directionLabel(direction)} this airport')),
                ] else if (value is Airline) ...[
                  Text(
                      'ICAO: ${value.icaoCode ?? "Unavailable"} · IATA: ${value.iataCode ?? "Unavailable"}'),
                  const Text(
                      'Airline reference data · OpenFlights. Matches known airline metadata or operational ICAO callsign prefix; does not verify a commercial flight number.'),
                  FilledButton(
                      onPressed: () => filter(AircraftFilter(
                          label: 'Airline: ${value.name}', airline: value)),
                      child: const Text('Filter radar / map by this airline')),
                ] else if (value is TrackedAircraft) ...[
                  if (result.type == SearchResultType.route)
                    FilledButton(
                        onPressed: () => filter(AircraftFilter(
                            label: 'Route: ${result.title}',
                            routeOrigin:
                                value.flight?.origin ?? value.route?.origin,
                            routeDestination: value.flight?.destination ??
                                value.route?.destination)),
                        child: const Text('Filter radar / map by this route'))
                  else
                    FilledButton(
                        onPressed: () => filter(AircraftFilter(
                            label: 'Aircraft: ${result.title}',
                            icao24: value.state.icao24)),
                        child: const Text('Show only this aircraft')),
                ],
                const SizedBox(height: 8),
                const Text(
                    'Filters apply to acquired aircraft only and replace the previous search filter. Other settings still apply.'),
              ]),
        );
      },
    );
  }

  String _directionLabel(AirportDirection direction) => switch (direction) {
        AirportDirection.either => 'From or to',
        AirportDirection.origin => 'From',
        AirportDirection.destination => 'To',
      };

  FollowedItem? _followed(SearchResult result) {
    final type = switch (result.type) {
      SearchResultType.aircraft => FollowedItemType.aircraft,
      SearchResultType.flight => FollowedItemType.flight,
      SearchResultType.airline => FollowedItemType.airline,
      SearchResultType.route => FollowedItemType.route,
      SearchResultType.airport => FollowedItemType.airport,
    };
    final value = result.value;
    final identifier = value is Airline
        ? value.identifier
        : value is Airport
            ? value.icao
            : result.identifier;
    return FollowedItem(
        type: type,
        identifier: identifier,
        label: result.title,
        subtitle: result.subtitle);
  }

  String _heading(SearchResultType type) => switch (type) {
        SearchResultType.flight => 'FLIGHTS',
        SearchResultType.aircraft => 'AIRCRAFT',
        SearchResultType.airline => 'AIRLINES',
        SearchResultType.route => 'ROUTES',
        SearchResultType.airport => 'AIRPORTS',
      };
}

class _SearchGuidance extends StatelessWidget {
  const _SearchGuidance({
    required this.hasSubmitted,
    required this.examples,
    required this.onExampleSelected,
  });

  final bool hasSubmitted;
  final List<String> examples;
  final ValueChanged<String> onExampleSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(hasSubmitted ? Icons.search_off : Icons.travel_explore,
              size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            hasSubmitted
                ? 'No matching results. Try another example.'
                : 'Search live aircraft and flights, or discover airports and airlines worldwide.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Live aircraft results use the current radar area. Airport and airline results come from the global discovery catalog.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          const Text('TRY AN EXAMPLE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: examples
                .map((example) => ActionChip(
                      key: Key('searchExample-$example'),
                      label: Text(example),
                      onPressed: () => onExampleSelected(example),
                    ))
                .toList(growable: false),
          ),
          const _CatalogAttribution(),
        ]),
      );
}

class _CatalogAttribution extends StatelessWidget {
  const _CatalogAttribution();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          'Airport data: OurAirports (Public Domain) · Airline data: OpenFlights (ODbL)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}
