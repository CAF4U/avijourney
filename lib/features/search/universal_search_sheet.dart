import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/models/airline.dart';
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
        ),
      ),
    );

class _UniversalSearchSheet extends StatefulWidget {
  const _UniversalSearchSheet(
      {required this.controller, required this.onShowOnMap});
  final AppController controller;
  final VoidCallback onShowOnMap;

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

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final query = value ?? _query.text;
    _query.text = query;
    _query.selection = TextSelection.collapsed(offset: query.length);
    setState(() {
      _hasSubmitted = true;
      _results = widget.controller.search(query);
    });
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
        trailing: IconButton(
          tooltip: followed != null && widget.controller.isFollowing(followed)
              ? 'Unfollow'
              : 'Follow',
          onPressed: followed == null
              ? null
              : () =>
                  setState(() => widget.controller.toggleFollowed(followed)),
          icon: Icon(followed != null && widget.controller.isFollowing(followed)
              ? Icons.bookmark
              : Icons.bookmark_border),
        ),
        onTap: () {
          final tracked = result.value;
          if (tracked is TrackedAircraft) {
            if (result.type == SearchResultType.flight) {
              showFlightDetail(context, tracked, widget.controller,
                  onShowOnMap: widget.onShowOnMap);
            } else {
              widget.controller.select(tracked.state.icao24);
              showAircraftDetail(context, tracked, widget.controller);
            }
          }
        },
      ),
    );
  }

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
