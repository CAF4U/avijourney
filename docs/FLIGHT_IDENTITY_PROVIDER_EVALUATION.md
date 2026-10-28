# Commercial Flight Identity Provider Evaluation

Reviewed: 28 October 2026

## Decision

No commercial-flight identity provider is enabled in the Android application.
The existing cached `NoOpFlightIdentityProvider` remains the production
implementation, so an unresolved OpenSky callsign stays primary and AviJourney
never manufactures a passenger-facing flight number.

AirLabs is the strongest technical candidate for a future server-side adapter:
its live-flight record can contain the aircraft hex/registration, operational
ICAO flight identifier and IATA commercial identifier together. That can form a
verifiable mapping only when the returned aircraft identity matches the
OpenSky aircraft and the observation is current. It is not integrated now
because AviJourney has no credential-holding backend, an API key must not be
shipped in an APK, and redistribution/caching rights need written confirmation
for this product.

## Verification rule for any future adapter

A result may be marked `FlightVerificationState.verified` only when one
authoritative provider record establishes all of the following:

1. the same physical aircraft (`icao24`/hex preferred, registration as a
   secondary check);
2. the same current operational flight/callsign;
3. the passenger-facing IATA commercial flight number;
4. a compatible observation/service date and route when supplied; and
5. provider name, retrieval time and source record identity for provenance.

Airline-code substitution, callsign-prefix conversion, route similarity or a
schedule-only candidate is never sufficient. Ambiguous, stale or conflicting
results remain unresolved and are negative-cached.

## Provider findings

Prices and plan terms below are the public figures visible on the review date;
they can change and must be rechecked before procurement.

| Provider | Identity suitability | Public cost / access | Licensing and deployment finding |
| --- | --- | --- | --- |
| [AirLabs](https://airlabs.co/travel-apis-for-developers) | Best technical match. Live records document `hex`, registration, `flight_icao` and `flight_iata` together. | [Public comparison](https://airlabs.co/) advertises a free package and about US$19/month for 10k real-time-flight requests. | Requires an API key; temporary signatures still require a trusted signer. Public terms do not give enough certainty for cached redistribution in a consumer APK. Candidate for a backend proof-of-concept after licensing confirmation. |
| [FlightAware AeroAPI](https://www.flightaware.com/commercial/aeroapi/) | Strong global flight identity, canonical identifiers and alternate/codeshare handling. A callsign alone may still be ambiguous. | Personal has no minimum and up to US$5 monthly credit; Standard has a US$100/month minimum plus per-result-set fees; Premium starts at US$1,000/month. | Personal is personal/academic only. Standard permits B2C use. The [Personal License](https://www.flightaware.com/commercial/aeroapi/AeroAPI_Personal_License.pdf) restricts combining its data with another real-time provider without permission, so it is not suitable for the current OpenSky-based APK. |
| [aviationstack](https://aviationstack.com/pricing) | Real-time flight data exposes commercial and operational identifiers, but the public material does not establish a safe arbitrary OpenSky-callsign/aircraft correlation contract. | Free: 100 requests/month, non-commercial. Basic: US$49.99/month for 10k requests and commercial use; higher plans from US$149.99/month. | Could support direct flight-number searches, but not selected for callsign enrichment without a trusted correlation key and server-side credential protection. |
| [Cirium Flex APIs](https://developer.flightstats.com/getting-started/) | Established schedules and flight-status data; potentially suitable with contracted identity semantics. | Evaluation: 20,000 lifetime transactions with endpoint sub-limits. Commercial is usage-based; premium/contract pricing is not public. | Requires App ID/key and commercial terms. A sales/technical validation is needed before treating a callsign mapping as verified. |
| [AeroDataBox](https://aerodatabox.com/pricing) | Flight-status/search coverage is useful, but the provider documents regional completeness limitations rather than universal coverage. | Direct plans start at US$19/month; marketplace plans from US$7.50/month. Derived-work licensing is advertised from US$499/month direct or US$187.50/month via API.Market. | Useful candidate where coverage exists, but caching, derived-work rights and aircraft-to-flight correlation must be validated for AviJourney's distribution model. |
| [OpenSky Network](https://openskynetwork.github.io/opensky-api/rest.html) | Supplies surveillance callsign/state, not a verified passenger commercial flight number. | Existing free/open position source subject to OpenSky access limits and terms. | Remains the position source only. It cannot verify `BAW7LC -> BA783`. |

## Deployment prerequisites for enrichment

- a small backend/proxy that holds credentials and enforces quota;
- provider approval for consumer-app display, caching and combination with
  OpenSky/HexDB;
- exact-record correlation using aircraft identity and time, not string
  inference;
- positive and negative TTL caching plus rate-limit/error handling;
- mocked contract tests and a monitored limited rollout.

Until those conditions are met, showing the operational callsign is more
accurate than displaying an attractive but unverified commercial number.
