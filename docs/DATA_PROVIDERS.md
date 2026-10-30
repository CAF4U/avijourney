# CAF4U Aircraft Companion Data Providers

## Provider philosophy

Every external service is replaceable. Provider-specific JSON structures terminate in the data layer and never leak into widgets.

## OpenSky — initial live-position provider

Use for ICAO24, callsign, latitude/longitude, altitude, velocity, track, vertical rate, squawk/on-ground/last-contact when supplied.

Use geographically bounded requests rather than global queries.

### Free-first quota strategy

- Default refresh: 60 seconds initially.
- Expose supported refresh choices in settings.
- Pause or slow requests while backgrounded.
- Keep the last valid snapshot.
- Surface rate limiting clearly.
- Never trigger refreshes merely because widgets rebuild.

### V0.3 implementation notes

The live implementation uses an anonymous, geographically bounded
`/api/states/all` request. CAF4U Aircraft Companion enforces a minimum 30-second acquisition
cadence, pauses the central timer outside the foreground, and retains the last
valid snapshot when OpenSky is offline, rate limited, or temporarily fails.
Optional OAuth client credentials may be added later without changing widgets
or domain models.

## HexDB — initial enrichment provider

Use for registration, type/model, operator/registered owner, callsign route where supplied and airport metadata.

### Caching

- aircraft identity key: ICAO24;
- route key: callsign plus suitable context;
- airport metadata key: ICAO/IATA;
- successful static identity lookups get long TTLs;
- failed/negative results get shorter retry TTLs.

The V0.3 HexDB adapter keeps successful identity, route and airport results for
30 days in memory and negative/error results for 15 minutes. This avoids repeat
enrichment requests during each OpenSky refresh and remains comfortably below
HexDB's published free-use request guidance. Enrichment errors never discard a
valid OpenSky position.

## Tracking centre and local state

The default first-launch centre is London Heathrow. Users may replace it with a
foreground device position, an airport from the embedded offline search catalog,
or a point selected on the map. The chosen centre, radar/filter settings and
saved aircraft identifiers are stored locally with `shared_preferences`.

## Map data

V0.3 requires a real map, but the tile supplier must be configurable. Respect attribution/licensing and avoid permanent coupling to one public tile service.

## Flight identity provider

ATC callsigns such as `BAW7LC` are not reliably reversible into passenger-facing numbers such as `BA783`.

The provider-independent `FlightIdentityProvider` and its positive/negative TTL
cache are implemented. No external commercial-flight source is enabled in the
production app yet: the currently reviewed free endpoints either require
credentials, have usage terms unsuitable for an anonymous mobile client, or do
not reliably verify the callsign-to-passenger-number relationship. The
production adapter therefore returns an honest unresolved result and leaves the
operational callsign primary. Tests inject verified provider results.

Future sources may include schedule APIs, airport public feeds or cached
confirmed mappings. A provider result must explicitly mark the identity as
verified and preserve its provenance before a commercial number is displayed as
primary. Airline-code metadata is presentation/search assistance only and is
never used to convert `BAW...` into `BA...`.

Results should carry provenance/confidence.

## Universal search and follows

Universal search is local and submit-driven. It combines the last live OpenSky
snapshot, HexDB aircraft/route enrichment, the embedded airport catalog,
lightweight static airline metadata and any verified flight results already
attached to that snapshot. It does not make a provider request for each
keystroke. External flight lookup caching remains at the provider boundary.

Aircraft, flights, airlines, routes and airports can be followed through a
provider-independent typed identifier stored locally. Following does not imply
notifications, cloud sync or a provider subscription.

### Global discovery catalogs

Airport and airline discovery is deliberately separate from the current
OpenSky tracking radius. The APK bundles 4,000+ scheduled-service airports from
[OurAirports](https://ourairports.com/data/) (Public Domain) and 1,200+ coded
airline records from [OpenFlights](https://openflights.org/data.php) (ODbL).
Catalog load failure falls back to the smaller built-in catalog and never
blocks the app shell. These reference catalogs do not verify schedules, current
operation or commercial flight numbers.

The full commercial identity provider review, costs, licensing concerns and
future verification contract are documented in
[`FLIGHT_IDENTITY_PROVIDER_EVALUATION.md`](FLIGHT_IDENTITY_PROVIDER_EVALUATION.md).
No deployable provider currently satisfies both the correlation and Android
credential/licensing requirements, so production enrichment remains unresolved
and the callsign remains primary.
