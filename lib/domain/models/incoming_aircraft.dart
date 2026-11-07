import 'airport.dart';
import 'tracked_aircraft.dart';

enum IncomingState {
  candidate,
  onGroundNearby,
  groundElsewhere,
  routeUnknown,
  differentDestination,
  sameFlight,
  stale,
  notObserved,
  lookupFailed,
  identityConflict
}

class IncomingAircraft {
  const IncomingAircraft(
      {required this.airport,
      required this.address,
      required this.state,
      required this.checkedAt,
      required this.evidence,
      this.aircraft,
      this.outboundCallsign});
  final String? outboundCallsign;
  final Airport airport;
  final String address;
  final IncomingState state;
  final DateTime checkedAt;
  final String evidence;
  final TrackedAircraft? aircraft;
  String get label => switch (state) {
        IncomingState.candidate => 'Likely incoming aircraft',
        IncomingState.onGroundNearby => 'Aircraft on ground near airport',
        IncomingState.groundElsewhere => 'Aircraft on ground elsewhere',
        IncomingState.routeUnknown =>
          'Aircraft located · inbound route unconfirmed',
        IncomingState.differentDestination =>
          'Aircraft route does not arrive here',
        IncomingState.sameFlight =>
          'Same flight observed · preceding leg not identified',
        IncomingState.stale => 'Aircraft position stale or undated',
        IncomingState.notObserved => 'Aircraft not currently observed',
        IncomingState.lookupFailed => 'Aircraft lookup unavailable',
        IncomingState.identityConflict => 'Aircraft identity conflict',
      };
}
