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
  SearchResult? _selection;
  SearchResultType? _category;
  AirportDirection _airportDirection = AirportDirection.either;

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
      _selection = null;
      _submittedQuery = query.trim();
      _results = widget.controller.search(query);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _contents(context));

  Widget _contents(BuildContext context) {
    if (_selection != null) return _drilldown(_selection!);
    final types = UniversalSearchService.routeCodes(_submittedQuery) == null
        ? SearchResultType.values
        : [
            SearchResultType.route,
            ...SearchResultType.values.where((t) => t != SearchResultType.route)
          ];
    final grouped = <SearchResultType, List<SearchResult>>{};
    for (final result
        in _results.where((r) => _category == null || r.type == _category)) {
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
      if (_results.isNotEmpty)
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              ChoiceChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null)),
              for (final type in SearchResultType.values)
                Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                        key: Key('searchCategory-${type.name}'),
                        label: Text(
                            '${_heading(type).toLowerCase()} (${_results.where((r) => r.type == type).length})'),
                        selected: _category == type,
                        onSelected: (_) => setState(() => _category = type))),
            ])),
      if (_hasSubmitted && _submittedQuery.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextButton.icon(
            key: const Key('filterSearchResults'),
            onPressed: () => _applyFilter(AircraftFilter(
                label: 'Search: $_submittedQuery', query: _submittedQuery)),
            icon: const Icon(Icons.filter_alt),
            label: const Text('Apply search as a display filter'),
          ),
        ),
      Expanded(
        child: _results.isNotEmpty && grouped.isEmpty
            ? const Center(child: Text('No results in this category'))
            : _results.isEmpty
                ? _SearchGuidance(
                    hasSubmitted: _hasSubmitted,
                    examples: _examples,
                    onExampleSelected: _submit,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      for (final type in types)
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
        key: Key('searchResult-${result.type.name}-${result.identifier}'),
        leading: Icon(_resultIcon(result.type)),
        title: Text(result.title),
        subtitle: Text('${result.subtitle}\n${result.matchReason}'),
        isThreeLine: true,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
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
          const Icon(Icons.chevron_right),
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
            setState(() {
              _selection = result;
              _airportDirection = AirportDirection.either;
            });
          }
        },
      ),
    );
  }

  void _applyFilter(AircraftFilter filter) {
    widget.controller.setDisplayFilter(filter);
    Navigator.pop(context);
  }

  IconData _resultIcon(SearchResultType type) => switch (type) {
        SearchResultType.aircraft => Icons.airplanemode_active,
        SearchResultType.flight => Icons.flight_takeoff,
        SearchResultType.route => Icons.route,
        SearchResultType.airport => Icons.local_airport,
        SearchResultType.airline => Icons.business,
      };

  AircraftFilter _selectionFilter(SearchResult result) {
    final value = result.value;
    if (value is AircraftRoute)
      return AircraftFilter(
          label: 'Route: ${value.label}',
          routeOrigin: value.origin,
          routeDestination: value.destination);
    if (value is Airline)
      return AircraftFilter(label: 'Airline: ${value.name}', airline: value);
    if (value is Airport)
      return AircraftFilter(
          label: '${_directionLabel(_airportDirection)} ${value.displayCode}',
          airport: value,
          direction: _airportDirection);
    return AircraftFilter(label: result.title, query: _submittedQuery);
  }

  Widget _drilldown(SearchResult result) {
    final value = result.value;
    final filter = _selectionFilter(result);
    final aircraft = widget.controller.aircraft
        .where((a) => filter.matches(a, matchesQuery: false))
        .toList(growable: false);
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Row(children: [
            IconButton(
                key: const Key('backToSearchResults'),
                tooltip: 'Back to search results',
                onPressed: () => setState(() => _selection = null),
                icon: const Icon(Icons.arrow_back)),
            Expanded(
                child: Text(result.title,
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                tooltip: 'Close search',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ])),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
            Text(result.subtitle),
            const SizedBox(height: 8),
            if (value is Airport) ...[
              Text(
                  'ICAO: ${value.icao} · IATA: ${value.iata ?? "Unavailable"}'),
              FilledButton.icon(
                  key: const Key('trackSelectedAirport'),
                  onPressed: value.latitude == null || value.longitude == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onTrackAirport(value);
                        },
                  icon: const Icon(Icons.radar),
                  label: const Text('Track around this airport')),
              Wrap(spacing: 8, children: [
                for (final direction in AirportDirection.values)
                  ChoiceChip(
                      label: Text(_directionLabel(direction)),
                      selected: direction == _airportDirection,
                      onSelected: (_) =>
                          setState(() => _airportDirection = direction)),
              ]),
            ],
            if (value is AircraftRoute) ...[
              const Text(
                  'Airport connection, not a confirmed scheduled service or actual flight path.'),
              OutlinedButton.icon(
                  key: const Key('routeAircraftMap'),
                  onPressed: !value.hasCoordinates
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onShowRoute(value, true);
                        },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Show route and aircraft on map')),
              OutlinedButton.icon(
                  key: const Key('routeAircraftList'),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onShowRoute(value, false);
                  },
                  icon: const Icon(Icons.view_list),
                  label: const Text('Open aircraft list')),
            ] else
              OutlinedButton.icon(
                  onPressed: () => _applyFilter(filter),
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Show matching aircraft on radar / map')),
            const SizedBox(height: 16),
            Text('AIRCRAFT · ${aircraft.length}',
                style: Theme.of(context).textTheme.titleMedium),
            const Text(
                'Observed aircraft in the current tracking area with known matching information.'),
            if (aircraft.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                      'No matching aircraft in the current tracking area. This does not mean no aircraft are flying this route.')),
            for (final tracked in aircraft)
              Card(
                  child: ListTile(
                key: Key('drilldownAircraft-${tracked.state.icao24}'),
                leading: const Icon(Icons.airplanemode_active),
                title: Text(tracked.primaryIdentifier),
                subtitle: Text([
                  tracked.identity?.registration,
                  tracked.identity?.model,
                  if ((tracked.flight?.origin ?? tracked.route?.origin)
                      case final origin?)
                    '${origin.displayCode} → ${(tracked.flight?.destination ?? tracked.route?.destination)?.displayCode ?? "Unknown"}',
                ].whereType<String>().join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  widget.controller.select(tracked.state.icao24);
                  showAircraftDetail(context, tracked, widget.controller);
                },
              )),
            const _CatalogAttribution(),
          ])),
    ]);
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
