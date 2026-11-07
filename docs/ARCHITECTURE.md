# CAF4U Aircraft Companion V0.3 Architecture

## Principle

UI features depend on domain abstractions. Domain code must not depend on OpenSky, HexDB, HTTP libraries or map vendors.

```text
Presentation
    |
Application / repositories
    |
Domain interfaces + models
    |
Data provider implementations
    |--- OpenSky
    |--- HexDB
    |--- map tile provider
    |--- local cache
    `--- future flight identity source
```

## Suggested structure

```text
lib/
  app/
  core/
    cache/
    errors/
    lifecycle/
    networking/
    theme/
  domain/
    models/
    providers/
    repositories/
  data/
    opensky/
    hexdb/
    local/
    mapping/
  features/
    radar/
    map/
    cards/
    aircraft_detail/
    filters/
    saved/
```

## Domain split

### AircraftState
Fast-changing surveillance data: ICAO24, callsign, position, altitude, speed, track, vertical rate, squawk and observation time.

### AircraftIdentity
Slow-changing identity: registration, type, model, manufacturer and operator.

### FlightRoute
Route enrichment only: callsign, origin, destination and provenance. It never
contains or verifies a passenger commercial flight number.

### Airport
ICAO, IATA, name, city, country and coordinates where available.

### TrackedAircraft
Presentation/application aggregate composed from state + identity + route.

### Flight

An operational journey, distinct from the physical airframe. It may contain a
verified commercial number, operational callsign, airline, schedule, status,
route, aircraft reference, provenance and verification state. A flight may
reference an aircraft, while an aircraft can operate many flights over time;
commercial flight numbers are therefore never stored on `AircraftIdentity`.

`FlightRoute` remains route enrichment associated with a callsign. It cannot by
itself verify a passenger-facing flight number.

## Flight identity and search

`FlightIdentityProvider` resolves a callsign to a provider-independent `Flight`.
Only a result explicitly marked `verified` with source provenance can make its
commercial number the primary identifier. Production currently uses a cached
no-op implementation, preserving unresolved callsigns until a sufficiently
reliable credential-free schedule source is selected.

Universal search is a submit-driven application service. It token-normalizes a
single query and searches the current shared aircraft snapshot, flight/route
data and HexDB enrichment. In parallel it searches bundled global airport and
airline catalogs that are not constrained by the tracking centre/radar range.
Widgets neither query providers nor issue requests on keystrokes. Catalog
providers initialize before the first refresh and fall back locally on failure.

`FollowedItem` stores a type (`aircraft`, `flight`, `airline`, `route` or
`airport`), stable identifier and display metadata. The local preferences store
persists these items; legacy saved-aircraft identifiers are migrated into the
same model while the existing saved-aircraft API remains compatible.

## Repository responsibilities

- merge live state with cached enrichment;
- deduplicate enrichment requests;
- retain last valid snapshot;
- manage refresh cadence;
- expose provider health;
- append observed position history;
- persist saved aircraft;
- emit immutable app state to widgets.

## Mapping

Use a real Flutter slippy-map implementation behind an adapter/component boundary. Aircraft markers must use geographic coordinates. The map provider must be replaceable and attribution supported. Never implement another hand-drawn pseudo-map.

## State management

Choose one predictable Flutter state-management approach and use it consistently. Keep network requests out of widget `build()` methods.

## Error model

Use typed categories such as network unavailable, timeout, unauthorized, rate limited, service unavailable, malformed response and unknown provider error.

## Caching

At minimum:

- short-lived live snapshot cache;
- ICAO24 -> aircraft identity cache;
- callsign/context -> route cache;
- airport code -> airport metadata cache;
- persistent saved-aircraft store.
- cached verified-flight lookup, including shorter-lived negative results;
- persistent typed followed-item store.
