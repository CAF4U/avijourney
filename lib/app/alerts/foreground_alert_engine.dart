import 'dart:math' as math;
import '../../domain/models/aircraft_alert.dart';
import '../../domain/models/aircraft_state.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/tracked_aircraft.dart';
import '../../domain/models/tracking_center.dart';

/// Only fed successful foreground acquisitions. Never treats missing coverage as an exit.
class ForegroundAlertEngine {
  final _previous = <String, _Observation>{};
  final _lastEmission = <String, DateTime>{};
  bool _baseline = true;
  void resetBaseline() {
    _previous.clear();
    _baseline = true;
  }

  List<AircraftAlert> process(
      {required List<TrackedAircraft> aircraft,
      required TrackingCenter center,
      required AppSettings settings,
      required Set<String> followed,
      required DateTime now}) {
    if (!settings.foregroundAlerts) {
      resetBaseline();
      return [];
    }
    _lastEmission
        .removeWhere((_, t) => now.difference(t) > const Duration(minutes: 10));
    _previous.removeWhere(
        (_, o) => now.difference(o.time) > const Duration(minutes: 10));
    final events = <AircraftAlert>[];
    for (final tracked in aircraft) {
      final s = tracked.state;
      final id = s.icao24.toUpperCase();
      final time = s.positionTime;
      if (time == null ||
          now.difference(time) > const Duration(seconds: 90) ||
          time.isAfter(now.add(const Duration(seconds: 15)))) continue;
      final old = _previous[id];
      if (old != null && !time.isAfter(old.time)) continue;
      final inside = _inside(s, center, settings.radarRangeNm);
      final watched = followed.contains(id);
      void emit(AircraftAlertKind kind, String message, String detail) {
        final key = '$id-${kind.name}';
        final last = _lastEmission[key];
        if (last != null && now.difference(last) < const Duration(minutes: 10))
          return;
        _lastEmission[key] = now;
        events.add(AircraftAlert(
            id: '$key-${time.millisecondsSinceEpoch}',
            icao24: id,
            identifier: tracked.primaryIdentifier,
            kind: kind,
            occurredAt: time,
            message: message,
            detail: detail));
      }

      if (!_baseline &&
          inside &&
          watched &&
          settings.alertFollowedEntry &&
          (old == null || !old.inside)) {
        emit(
            AircraftAlertKind.detected,
            'Followed aircraft detected in tracking area',
            'First detected within ${settings.radarRangeNm} NM of ${center.label}. Coverage changes can cause a new detection; this is not an exact boundary-crossing time.');
      }
      if (inside &&
          (!settings.alertSquawkFollowedOnly || watched) &&
          old?.squawk != s.squawk) {
        if (s.squawk == '7600' && settings.alertSquawk7600)
          emit(AircraftAlertKind.squawk7600, 'Squawk 7600 reported',
              'Radio-communication failure code reported by the surveillance feed. Not independently verified.');
        if (s.squawk == '7700' && settings.alertSquawk7700)
          emit(AircraftAlertKind.squawk7700, 'Squawk 7700 reported',
              'Emergency code reported by the surveillance feed. Not independently verified.');
      }
      var stable = old?.stableGround;
      var stableTime = old?.stableTime ?? time;
      bool? candidate;
      var count = 0;
      final consecutive = old != null &&
          time.difference(old.time) <= const Duration(minutes: 3);
      if (s.hasGroundState) {
        if (!consecutive || stable == null) {
          stable = s.onGround;
          stableTime = time;
        } else if (s.onGround == stable) {
          stableTime = time;
        } else {
          candidate = s.onGround;
          count = old.candidate == candidate ? old.count + 1 : 1;
          if (count >= 2) {
            if (inside && watched && settings.alertFollowedMovement) {
              emit(
                  s.onGround
                      ? AircraftAlertKind.landingInferred
                      : AircraftAlertKind.takeoffInferred,
                  s.onGround ? 'Landing inferred' : 'Takeoff inferred',
                  'Two fresh observations confirm a reported ${s.onGround ? "airborne-to-ground" : "ground-to-airborne"} transition after $stableTime. Detected at $time; not an ACARS ON/OFF or exact wheels-event timestamp.');
            }
            stable = s.onGround;
            stableTime = time;
            candidate = null;
            count = 0;
          }
        }
      } else {
        stable = null;
      }
      _previous[id] = _Observation(
          time, inside, s.squawk, stable, stableTime, candidate, count);
    }
    _baseline = false;
    return events;
  }

  static bool _inside(AircraftState s, TrackingCenter c, int range) {
    double rad(double d) => d * math.pi / 180;
    final a = math.pow(math.sin(rad(s.latitude - c.latitude) / 2), 2) +
        math.cos(rad(c.latitude)) *
            math.cos(rad(s.latitude)) *
            math.pow(math.sin(rad(s.longitude - c.longitude) / 2), 2);
    return 6880.13 * math.asin(math.sqrt(a.clamp(0, 1))) <= range;
  }
}

class _Observation {
  _Observation(this.time, this.inside, this.squawk, this.stableGround,
      this.stableTime, this.candidate, this.count);
  final DateTime time;
  final bool inside;
  final String? squawk;
  final bool? stableGround;
  final DateTime stableTime;
  final bool? candidate;
  final int count;
}

String estimatedMovement(AircraftState s, {DateTime? now}) {
  final time = s.positionTime;
  if (time == null ||
      (now ?? DateTime.now()).difference(time) > const Duration(seconds: 90))
    return 'Movement unavailable (position stale or timestamp missing)';
  if (!s.hasGroundState) return 'Movement unknown (ground state unavailable)';
  if (!s.onGround) return 'Airborne (reported ground flag; phase estimated)';
  if (!s.hasSpeed) return 'On ground (speed unavailable)';
  if (s.groundSpeedKnots <= 3)
    return 'Stationary on ground (estimated; gate status unknown)';
  if (s.groundSpeedKnots >= 80) return 'High-speed ground movement (estimated)';
  return 'Moving on ground / possible taxi (estimated)';
}
