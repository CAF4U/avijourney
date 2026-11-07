import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../app/navigation/detail_navigation.dart';
import '../../domain/models/airport.dart';
import '../../domain/models/incoming_aircraft.dart';
import '../../domain/models/tracked_aircraft.dart';

Future<void> showIncomingAircraft(BuildContext context,
        AppController controller, TrackedAircraft aircraft,
        {Airport? initialAirport}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
            heightFactor: .9,
            child: _IncomingSheet(
                controller: controller,
                seed: aircraft,
                initialAirport: initialAirport)));

class _IncomingSheet extends StatefulWidget {
  const _IncomingSheet(
      {required this.controller, required this.seed, this.initialAirport});
  final AppController controller;
  final TrackedAircraft seed;
  final Airport? initialAirport;
  @override
  State<_IncomingSheet> createState() => _IncomingSheetState();
}

class _IncomingSheetState extends State<_IncomingSheet> {
  final _airportQuery = TextEditingController();
  Airport? _airport;
  IncomingAircraft? _result;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _airport = widget.initialAirport;
  }

  @override
  void dispose() {
    _airportQuery.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (_airport == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.controller.incomingService!.find(
          address:
              widget.seed.flight?.aircraftIcao24 ?? widget.seed.state.icao24,
          airport: _airport!,
          expectedRegistration: widget.seed.identity?.registration ??
              widget.seed.flight?.aircraftRegistration,
          outboundCallsign: widget.seed.state.callsign);
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'Lookup could not be completed. Try again later.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final target = result?.aircraft;
    final route = target?.route;
    final matches = _airportQuery.text.trim().isEmpty
        ? <Airport>[]
        : widget.controller.searchAirports(_airportQuery.text).take(8).toList();
    return ListView(
        key: const Key('incomingResultList'),
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            const Expanded(
                child: Text('Find incoming aircraft',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close))
          ]),
          Text(
              '${widget.seed.identity?.registration ?? widget.seed.flight?.aircraftRegistration ?? "Known aircraft"} · ${widget.seed.state.icao24.toUpperCase()}'),
          const SizedBox(height: 12),
          const Text(
              'Uses the aircraft linked to the selected record. Choose the airport your aircraft should arrive at before your departure.'),
          if (_airport != null)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flight_land),
                title: Text('${_airport!.displayCode} · ${_airport!.name}'),
                subtitle: const Text('Expected inbound airport')),
          TextField(
              key: const Key('incomingAirportSearch'),
              controller: _airportQuery,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'Change arrival airport',
                  hintText: 'ALC, Alicante …')),
          for (final airport in matches)
            ListTile(
                title: Text('${airport.displayCode} · ${airport.name}'),
                onTap: () => setState(() {
                      _airport = airport;
                      _airportQuery.clear();
                      _result = null;
                    })),
          const SizedBox(height: 12),
          FilledButton.icon(
              key: const Key('lookupIncomingAircraft'),
              onPressed: _airport == null ||
                      _busy ||
                      widget.controller.incomingService == null
                  ? null
                  : _find,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(_busy
                  ? 'Locating aircraft…'
                  : 'Locate aircraft and check inbound route')),
          const Text(
              'Targeted lookup beyond the scan area. Results and failed attempts are cached for 30 seconds. Receiver coverage and provider limits still apply.',
              style: TextStyle(fontSize: 12)),
          if (widget.controller.incomingService == null)
            const Text(
                'Targeted aircraft lookup is unavailable in this data configuration.'),
          if (_error != null) Text(_error!),
          if (result != null) ...[
            const SizedBox(height: 20),
            Text(result.label,
                key: const Key('incomingAssessment'),
                style: Theme.of(context).textTheme.titleLarge),
            if (target != null &&
                result.state != IncomingState.identityConflict)
              OutlinedButton.icon(
                  key: const Key('showIncomingOnMap'),
                  onPressed: () {
                    widget.controller.showIncomingOnMap(result);
                    final navigation = DetailNavigation.maybeOf(context);
                    if (navigation != null) {
                      navigation.aircraft(target);
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Show aircraft and known route on map')),
            if (target != null) ...[
              Text(
                  'Observed callsign: ${target.state.callsign.isEmpty ? "unavailable" : target.state.callsign}'),
              Text(
                  'Aircraft: ${target.identity?.registration ?? result.address.toUpperCase()}'),
              Text(
                  'Known route: ${route?.origin?.displayCode ?? "?"} → ${route?.destination?.displayCode ?? "?"}'),
              Text(
                  'Position observed: ${target.state.positionTime?.toUtc().toIso8601String() ?? "Unavailable"}'),
              Text(
                  'Reported state: ${!target.state.hasGroundState ? "Unknown" : target.state.onGround ? "On ground" : "Airborne"}'),
            ],
            Text('Lookup: ${result.checkedAt.toUtc().toIso8601String()}'),
            const SizedBox(height: 8),
            Text(result.evidence),
          ],
        ]);
  }
}
