import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/search/universal_search_service.dart';
import '../../domain/models/airline.dart';
import '../../domain/models/aircraft_filter.dart';
import '../../domain/models/aircraft_route.dart';
import '../../domain/models/airport.dart';
import '../../domain/models/followed_item.dart';
import '../../domain/models/search_result.dart';
import '../../domain/models/search_scope.dart';
import '../../core/widgets/manual_refresh_button.dart';
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
  SearchScope _scope = SearchScope.all;
  List<SearchResult> get _results => _hasSubmitted
      ? widget.controller.search(_submittedQuery, scope: _scope)
      : const [];
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
      _category = null;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _contents(context));

  Widget _contents(BuildContext context) {
    if (_selection != null) return _drilldown(_selection!);
    final results = _results;
    final types = UniversalSearchService.routeCodes(_submittedQuery) == null
        ? SearchResultType.values
        : [
            SearchResultType.route,
            ...SearchResultType.values.where((t) => t != SearchResultType.route)
          ];
    final grouped = <SearchResultType, List<SearchResult>>{};
    for (final result
        in results.where((r) => _category == null || r.type == _category)) {
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
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final scope in SearchScope.values)
            Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                    key: Key('searchScope-${scope.name}'),
                    label: Text(switch (scope) {
                      SearchScope.all => 'All available',
                      SearchScope.scanArea => 'Aircraft in scan area',
                      SearchScope.worldwideReference => 'Worldwide reference',
                    }),
                    selected: _scope == scope,
                    onSelected: (_) => setState(() {
                          _scope = scope;
                          _category = null;
                        }))),
        ]),
      ),
      Expanded(
          child: ListView(
        key: const Key('searchResultsList'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _coverage(),
          if (results.isNotEmpty)
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ChoiceChip(
                      label: const Text('All'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null)),
                  for (final type
                      in SearchResultType.values.where(_scope.includes))
                    Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                            key: Key('searchCategory-${type.name}'),
                            label: Text(
                                '${_heading(type).toLowerCase()} (${results.where((r) => r.type == type).length})'),
                            selected: _category == type,
                            onSelected: (_) =>
                                setState(() => _category = type))),
                ])),
          if (_hasSubmitted &&
              _submittedQuery.isNotEmpty &&
              _scope != SearchScope.worldwideReference)
            TextButton.icon(
                key: const Key('filterSearchResults'),
                onPressed: () => _applyFilter(AircraftFilter(
                    label: 'Search: $_submittedQuery', query: _submittedQuery)),
                icon: const Icon(Icons.filter_alt),
                label: const Text('Filter radar / map in this scan area')),
          if (results.isNotEmpty && grouped.isEmpty)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const Text(
                      'No results in this category. Other categories have matches.'),
                  TextButton(
                      onPressed: () => setState(() => _category = null),
                      child: const Text('Show all results')),
                ]))
          else if (results.isEmpty)
            _SearchGuidance(
                hasSubmitted: _hasSubmitted,
                query: _submittedQuery,
                scope: _scope,
                examples: _examples,
                onExampleSelected: _submit)
          else ...[
            for (final type in types)
              if (grouped[type]?.isNotEmpty == true) ...[
                Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(_heading(type),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                ...grouped[type]!.map(_tile),
              ],
          ],
          const _CatalogAttribution(),
        ],
      )),
    ]);
  }

  Widget _coverage() {
    final controller = widget.controller;
    final status = !controller.isActive
        ? 'Paused'
        : switch (controller.feedStatus) {
            FeedStatus.connecting => 'Connecting',
            FeedStatus.live => 'Live',
            FeedStatus.cached => 'Cached / stale',
            FeedStatus.offline => 'Offline',
            FeedStatus.rateLimited => 'Rate limited',
            FeedStatus.error => 'Feed error',
          };
    final observations = controller.aircraft.map((a) => a.state.observedAt);
    final latest = observations.isEmpty
        ? null
        : observations.reduce((a, b) => a.isAfter(b) ? a : b).toLocal();
    final time = latest == null
        ? 'No aircraft observations yet'
        : 'Observed ${latest.toIso8601String().substring(0, 10)} · ${latest.hour.toString().padLeft(2, '0')}:${latest.minute.toString().padLeft(2, '0')} local';
    return Card(
        key: const Key('searchCoverage'),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(
                        'Scan: ${controller.trackingCenter.label} · ${controller.settings.radarRangeNm} NM radius',
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                ManualRefreshButton(controller: controller, surface: 'search'),
                IconButton(
                    key: const Key('searchCapabilities'),
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        useSafeArea: true,
                        isScrollControlled: true,
                        builder: (_) => const SingleChildScrollView(
                            padding: EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Flight search and incoming aircraft',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 12),
                                  Text(
                                      'To locate a known aircraft beyond the scan area, open its aircraft or flight details and choose Find incoming aircraft. Flight-number schedules and automatic aircraft assignment lookup are not connected.'),
                                  SizedBox(height: 8),
                                  Text(
                                      'If you already know the aircraft registration, ICAO24 address or current callsign, search it in the scan area. A departing flight and its incoming leg usually have different callsigns.'),
                                  SizedBox(height: 8),
                                  Text(
                                      'Commercial flight numbers only match when verified data is available. We never convert an ATC callsign into a passenger flight number.'),
                                  SizedBox(height: 8),
                                  Text(
                                      'To look elsewhere: search an airport and select it to move the scan. You can also change the scan location in settings. A wider scan range may find more aircraft; coverage and identity data can still be incomplete.'),
                                ]))),
                    icon: const Icon(Icons.info_outline, size: 18),
                    tooltip: 'Flight numbers and incoming aircraft'),
              ]),
              Text('$status · ${controller.aircraft.length} acquired aircraft'),
              Text(time, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              const Text(
                  'Aircraft: scan area only. Airports, airlines, routes: worldwide reference.',
                  style: TextStyle(fontSize: 12)),
            ])));
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
          if (result.value is Airport || result.value is TrackedAircraft)
            IconButton(
                key: Key(
                    'searchDetails-${result.type.name}-${result.identifier}'),
                tooltip: result.value is Airport
                    ? 'Airport details and filters'
                    : 'Aircraft or flight details',
                onPressed: () => _openResultDetails(result),
                icon: const Icon(Icons.info_outline))
          else
            const Icon(Icons.chevron_right),
        ]),
        onTap: () {
          final value = result.value;
          if (value is TrackedAircraft &&
              result.type != SearchResultType.route) {
            widget.controller.select(value.state.icao24);
            Navigator.pop(context);
            widget.onShowOnMap();
          } else if (value is Airport &&
              value.latitude != null &&
              value.longitude != null) {
            Navigator.pop(context);
            widget.onTrackAirport(value);
          } else {
            _openResultDetails(result);
          }
        },
      ),
    );
  }

  void _openResultDetails(SearchResult result) {
    final value = result.value;
    if (value is TrackedAircraft) {
      widget.controller.select(value.state.icao24);
      if (result.type == SearchResultType.flight) {
        showFlightDetail(context, value, widget.controller, onShowOnMap: () {
          Navigator.pop(context);
          widget.onShowOnMap();
        });
      } else {
        showAircraftDetail(context, value, widget.controller);
      }
    } else {
      setState(() {
        _selection = result;
        _airportDirection = AirportDirection.either;
      });
    }
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
  const _SearchGuidance(
      {required this.hasSubmitted,
      required this.query,
      required this.scope,
      required this.examples,
      required this.onExampleSelected});
  final bool hasSubmitted;
  final String query;
  final SearchScope scope;
  final List<String> examples;
  final ValueChanged<String> onExampleSelected;

  @override
  Widget build(BuildContext context) {
    final flightNumber =
        RegExp(r'^[A-Z0-9]{2}\s*\d{1,4}[A-Z]?$', caseSensitive: false)
            .hasMatch(query.trim());
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(children: [
          Icon(hasSubmitted ? Icons.search_off : Icons.travel_explore,
              size: 40),
          const SizedBox(height: 12),
          Text(
              !hasSubmitted || query.isEmpty
                  ? 'Choose a search scope and enter an aircraft, airport, airline or route.'
                  : scope == SearchScope.worldwideReference
                      ? 'No reference match for "$query".'
                      : scope == SearchScope.scanArea
                          ? 'No acquired aircraft match for "$query" in this scan area.'
                          : 'No acquired aircraft or reference match for "$query".',
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          if (hasSubmitted && query.isNotEmpty) ...[
            if (scope != SearchScope.worldwideReference) ...[
              const Text(
                  'No match does not mean the aircraft is not flying. It may be outside the scan area, missing from provider coverage, or lack registration / route information.',
                  textAlign: TextAlign.center),
              if (flightNumber)
                const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                        'This looks like a commercial flight number. Verified flight-number lookup is not connected. Try the current callsign, registration or ICAO24 address; these search only acquired aircraft.',
                        textAlign: TextAlign.center)),
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'Try refreshing, increasing the scan range, or searching an airport to move the scan.',
                      textAlign: TextAlign.center)),
            ] else
              const Text(
                  'This scope searches airports, airlines and airport connections, not live aircraft or schedules. Use airport codes such as ALC-BRS for a route; some airports may be absent from the catalogue.',
                  textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          const Text('TRY AN EXAMPLE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: (scope == SearchScope.worldwideReference
                      ? ['ALC', 'LHR → LAX', 'British Airways']
                      : examples)
                  .map((example) => ActionChip(
                      key: Key('searchExample-$example'),
                      label: Text(example),
                      onPressed: () => onExampleSelected(example)))
                  .toList()),
        ]));
  }
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
