# Known-aircraft incoming lookup — V0.4.8

## User workflow

Open an aircraft or flight detail card and choose **Find incoming aircraft**.
The selected record supplies the aircraft address and registration. Its origin
is the initial expected inbound airport; change it with airport search if needed.
Choose **Locate aircraft and check inbound route**, inspect the evidence, then
**Show aircraft and known route on map**. The map includes a timestamped lookup
assessment, an update action and a clear action. No scheduled arrival time or
commercial flight number is invented.

## Data and inference

The existing OpenSky provider supports `states/all?icao24=<known address>` without
a geographic bounding box. This is a targeted single-airframe lookup, never an
unfiltered global snapshot. Coverage, quotas and existing licensing requirements
still apply; no additional subscription or credential is introduced.

The returned current callsign is enriched independently through HexDB. Outbound
callsign, route, commercial number and status are never copied into that incoming
record. A dedicated enrichment instance caches successful responses for five
minutes; the normal scan's long static cache is unchanged. The inference requires
a matching address, no known registration conflict, a position timestamp no older
than two minutes (future tolerance 30 seconds), reported airborne state, a different
callsign from the selected flight, and known destination matching the chosen
airport. It is a **likely** incoming leg, not verified operational assignment.
HexDB route data can be incomplete or outdated even when just retrieved.

Other outcomes explicitly cover ground within 3 NM of the airport (not a gate
arrival), ground elsewhere, same flight, route unknown/different destination,
stale/undated position, not observed, provider failure and identity conflict.
Identity conflicts cannot be opened on the map. Other located outcomes can be
inspected without being promoted to inbound candidates. Position survives route
or identity enrichment failure. Network failure is not reported as no aircraft.

Results, empty responses and failures are cached for 30 seconds per address;
concurrent lookups coalesce. Assessment is recomputed for each selected airport.
There is no background polling. Map updates use this cache and keep the camera
where the user placed it. Clearing/changing scan, route or display filters leaves
the incoming lookup view. The normal Map refresh continues to refresh scan data;
the incoming strip's update action refreshes the targeted aircraft.

Located aircraft remain in a separate map overlay. They never enter scan search,
radar, area-entry alerts, followed-aircraft transition history or the acquired
snapshot. Route camera fitting includes only the located target and known route
endpoints; connection lines are identified as airport connections, not tracks.
Lookup assessments and position times remain visible to distinguish a lookup
snapshot from continuous live tracking.

## Sources and limitations

- OpenSky targeted address parameter: https://openskynetwork.github.io/opensky-api/rest.html
- Existing HexDB callsign/aircraft resources: https://hexdb.io/
- Licensing context remains in DATA_PROVIDERS.md and INCOMING_AIRCRAFT_DATA_RESEARCH.md.

This implements the chain when the user already has the aircraft identity on a
record. It does not discover FR2291's assigned aircraft from the commercial number
alone, reconstruct historical rotations, guarantee worldwide reception, or derive
an ETA. Standalone registration-only lookup without a known address is outside
this first implementation. The existing search's airport/airline catalogue scope
is unchanged; the global lookup is an explicit action on a known aircraft.
