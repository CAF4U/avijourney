import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/models/airport.dart';
import '../../domain/providers/device_location_provider.dart';

Future<void> showTrackingLocationSheet(
  BuildContext context,
  AppController controller, {
  required VoidCallback onChooseOnMap,
}) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      builder: (context) => _TrackingLocationSheet(
        controller: controller,
        onChooseOnMap: onChooseOnMap,
      ),
    );

class _TrackingLocationSheet extends StatefulWidget {
  const _TrackingLocationSheet({
    required this.controller,
    required this.onChooseOnMap,
  });

  final AppController controller;
  final VoidCallback onChooseOnMap;

  @override
  State<_TrackingLocationSheet> createState() => _TrackingLocationSheetState();
}

class _TrackingLocationSheetState extends State<_TrackingLocationSheet> {
  bool _locating = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tracking location',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(widget.controller.trackingCenter.label,
                  key: const Key('trackingCenterLabel'),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold)),
              if (widget.controller.locationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(widget.controller.locationMessage!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 12),
              if (widget.controller.savedAirports.isNotEmpty) ...[
                Text('Saved airports',
                    style: Theme.of(context).textTheme.titleSmall),
                for (final airport in widget.controller.savedAirports)
                  ListTile(
                    key: Key('quickAirport-${airport.icao}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bookmark),
                    title: Text('${airport.displayCode} · ${airport.name}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _chooseAirport(airport),
                  ),
                const Divider(),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _locating
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                title: const Text('Use my location'),
                subtitle: const Text('Permission is requested only when used'),
                enabled: !_locating,
                onTap: _useCurrentLocation,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flight_takeoff),
                title: const Text('Choose airport'),
                subtitle: const Text('Search code, airport name or city'),
                onTap: () async {
                  final airport = await showSearch<Airport?>(
                    context: context,
                    delegate: _AirportSearchDelegate(widget.controller),
                  );
                  if (airport != null && mounted) _chooseAirport(airport);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_location_alt_outlined),
                title: const Text('Choose on map'),
                subtitle: const Text('Long-press the desired map point'),
                onTap: () {
                  widget.controller.beginMapCenterSelection();
                  Navigator.pop(context);
                  widget.onChooseOnMap();
                },
              ),
            ],
          ),
        )),
      );

  void _chooseAirport(Airport airport) {
    // Centre changes synchronously; close without waiting for the live feed.
    widget.controller.chooseAirport(airport);
    Navigator.pop(context);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final status = await widget.controller.useCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (status == DeviceLocationStatus.available) Navigator.pop(context);
  }
}

class _AirportSearchDelegate extends SearchDelegate<Airport?> {
  _AirportSearchDelegate(this.controller);
  final AppController controller;

  @override
  String get searchFieldLabel => 'Airport code, name or city';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          tooltip: 'Clear search',
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        tooltip: 'Back',
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final results = controller.searchAirports(query);
    if (results.isEmpty) return const Center(child: Text('No airports found'));
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final airport = results[index];
        return ListTile(
          leading: CircleAvatar(child: Text(airport.displayCode)),
          title: Text(airport.name),
          subtitle: Text([
            airport.icao,
            airport.city,
            airport.country,
          ].whereType<String>().join(' · ')),
          onTap: () => close(context, airport),
        );
      },
    );
  }
}
