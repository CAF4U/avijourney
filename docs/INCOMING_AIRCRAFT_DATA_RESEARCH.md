# Incoming aircraft identification: data gaps and implementation decision

Reviewed: 7 November 2026. Public documentation research only; no accounts,
subscriptions, API keys or paid requests were created. No supplier was contacted.
Prices and terms need reconfirmation before procurement. No authenticated
responses or airline coverage claims have been independently tested.

## Implementation update

V0.4.8 implements targeted global position lookup through the existing OpenSky ICAO24 filter and incoming-candidate inference using current callsign route enrichment. This requires a known aircraft address from the selected record and does not require a new subscription. See [implementation](INCOMING_AIRCRAFT_IMPLEMENTATION.md). The provider comparison below remains relevant to discovering an unknown assignment from a commercial flight number.

## Decision

Ship search usability improvements using existing acquired aircraft and offline
reference data. Do not present worldwide live search or an incoming-aircraft
button as available until a provider actually supplies the required information.

For a low-cost feasibility trial, AirLabs remains the first candidate, subject
to access to its registration/hex fields and written confirmation of app display,
cache and mixed-provider rights. For a direct provider-reported inbound link,
FlightAware AeroAPI is the strongest documented candidate, with a materially
higher commercial minimum and mixed-source permission requirement.

No free service was verified to reliably supply the complete pre-departure
assignment-to-inbound chain for a distributed CAF4U consumer app. This is a
research finding, not a claim that every possible supplier has been excluded.

## What the product must establish

The user's screenshots show FR2291 ALC–BRS on 7 November 2026 associated with
9H-VUA / 4D22FF, while that airframe was operating FR2715 LGW–ALC / RYR91RL.
These screenshots illustrate the requirement; they are not a live supplier test
or a lasting guarantee of that assignment. The outbound callsign RYR9LW differs
from the inbound callsign. Neither can be obtained by replacing FR with RYR.

| Step | Required evidence | Existing app |
| --- | --- | --- |
| Identify the departure | Flight number, service date, departure airport/time, codeshare handling and stable flight-instance ID | No schedule provider |
| Identify the assigned airframe | Registration and preferably ICAO24, assignment time and source, distinction between planned type and actual registration | Static aircraft identity only after local acquisition |
| Establish the preceding flight | Explicit inbound relationship, or same registration with a temporally compatible leg arriving at the departure airport | No aircraft rotation feed |
| Locate the airframe | Current position, observation timestamp and data source outside the user's scan area | Current scan snapshot only |
| Keep it honest | Changes of aircraft, missing/conflicting data, stale assignment and lack of reception | Existing cache/provenance patterns can be reused |

The last flight seen for a registration is not automatically the incoming leg.
An aircraft might be parked, repositioning, diverted or assigned elsewhere.
An inferred same-airframe relationship must be labelled as a candidate, not a
provider-confirmed assignment. Missing registration must remain unresolved.

## Provider comparison

| Provider | Documented capability | Cost/access | Remaining gap and recommendation |
| --- | --- | --- | --- |
| FlightAware AeroAPI | Flight records include registration and `inbound_fa_flight_id` when known. Flight lookup and current-position endpoints can complete the chain. | Personal credit is not a commercial licence. Standard B2C tier publishes a US$100/month minimum; usage is charged per result set. | Best documented direct relationship, still nullable and coverage-dependent. Standard licence requires prior written permission to combine its data with another real-time/near-real-time provider. Obtain permission for the existing stack before a trial in the product. |
| AirLabs | `/flight?flight_iata=...` describes a current/scheduled flight with registration/hex when available. `/flights?reg_number=...` finds the currently tracked airframe. | Free package advertised. Public pages advertise 1,000 monthly trial/development queries, but field entitlements and current dashboard pricing must be verified. | Good feasibility candidate. Closest-instance flight lookup is ambiguous for repeated flights; disambiguate date/airport/time. No explicit inbound-link field was found in the reviewed documentation. Schedules document a limited forward window and do not document registration as a returned field. Validate that the outbound registration exists *before departure*, and validate historical/landed incoming cases. |
| Flightradar24 public API | Live positions and flight summaries support registration, callsign, route and time searches. | Paid subscription plus credits. Consumer app subscription is separate from API access. | The official FAQ explicitly says future scheduled flights shown in the consumer app are not exposed in the API. It cannot alone guarantee assignment lookup for a departure that is not yet tracked. Flight-number derivation semantics also need validation against CAF4U's verification rules. Do not assume screenshot features are API features. |
| adsb.lol | Documented lookup by registration, ICAO24 and callsign, independent of a local scan. ODbL data; free/best-effort access. | Production contact requested; current request page describes keys and possible limits. No guaranteed free production capacity. | Candidate for known-airframe global position only. Does not establish a future departure's assigned airframe or incoming relationship. Confirm attribution/database obligations, access and capacity before integrating. |
| FlyItalyADSB | Provider repository advertises registration/hex/callsign lookup and commercial use on a free plan, with CC BY-SA attribution. | Self-service key, stated free limits and no SLA; product-wide quota. | Additional free-first global-position candidate. Coverage/reliability and data licence compatibility require validation. No documented commercial-flight assignment/inbound chain. Published claims were not tested. |
| OpenSky | Surveillance states and retrospectively inferred flights. Its FAQ says it does not map to commercial schedules. | Current terms require written licensing for commercial entities and operational REST API use. | Cannot supply the missing commercial assignment. Confirm the app's existing written agreement before broader deployment; HTTP access is not licence approval. |

### Important licence update

The earlier evaluation mentioned FlightAware's mixed-source restriction under
its Personal licence. The published **Standard** licence also contains that
restriction (Licensee May Not, item 10), and limits raw retention to 30 days.
Purchasing Standard by itself therefore does not settle combination rights.

OpenSky's current terms are more restrictive than the earlier documentation's
general free/open wording. The current terms take precedence over an older FAQ
description. This research does not establish whether CAF4U already has an
agreement; that must be checked. This change does not replace or disable any
existing provider.

## Minimum future technical contract (preparation only)

Keep this capability separate from scan acquisition. The current
`FlightIdentityProvider.resolveVerifiedIdentity(callsign)` alone is insufficient
for finding a future flight by date, resolving an assignment and following its
incoming leg. Do not overload it with guessed identities.

A future server endpoint should accept a commercial flight identifier, service
date and optional departure airport. Return a list of distinct flight instances
when ambiguous, with a stable provider instance ID, scheduled/estimated times,
UTC timestamps and airport time zones. Selecting an instance resolves:

- assignment: registration/ICAO24, reported-at time, source and confirmation state;
- incoming leg: its own flight ID, route, callsign and explicit relationship basis;
- position: independently timestamped, source-attributed aircraft state;
- state: unavailable, ambiguous, candidate, provider-reported, stale or changed.

Credentials stay on a protected backend. Add product-wide quota and spending
caps, rate limits, provider-approved cache/negative-cache lifetimes and backoff.
Poll only a user-selected flight while relevant; do not run a global schedule
crawler. Do not mix globally found aircraft into the scan snapshot or trigger
area-entry alerts until the aircraft is actually acquired inside the scan.
Aircraft/Flight domain separation and independent operation from Travel
Companion remain mandatory. No backend or integration is introduced here.

## Concrete next step and acceptance tests

1. Establish an AirLabs free account/key through the user and confirm the exact
   plan fields: outbound pre-departure registration/hex, timestamp semantics,
   flight-instance disambiguation and registration lookup. Confirm consumer-app
   display, combination with OpenSky/HexDB, caching and redistribution rights.
2. In parallel, obtain a FlightAware quote/permission covering the existing
   mixed-source app, Standard inbound-link availability, retention, attribution
   and the US$100 minimum. Do not purchase on the assumption of Personal credit.
3. Test a small server-side, quota-capped trial on contemporary Ryanair/Malta
   Air routes plus other airlines. Record redacted payloads with retrieval time.
   A November 2026 screenshot is not proof of a supplier's current coverage.
4. Test a departure before its incoming leg lands, landed incoming aircraft,
   assignment absent, last-minute swap, repeated flight number, codeshare,
   midnight/time-zone crossing, diversion, no ADS-B coverage and stale response.
   A reference-only result must never become a confirmed aircraft assignment.
5. Only enable the feature after a supplier's pre-departure assignment and
   relationship semantics pass. If AirLabs supplies only a current position,
   scope it to global known-aircraft lookup and keep incoming identification
   unavailable rather than assuming a preceding-flight relationship.

Cost planning must include all users, result pages and refreshes. For example,
two flight lookups at the published AeroAPI US$0.005/result-set rate cost
US$0.01 for a single-page chain, before positions/refreshes and the monthly
minimum. This is an illustrative calculation, not an operating-cost quote.

## Primary sources checked

- FlightAware product, tiers and query fees: https://www.flightaware.com/commercial/aeroapi/
- FlightAware v4 migration guide (inbound relationship field): https://7228775.fs1.hubspotusercontent-na1.net/hubfs/7228775/AeroAPI%20V4%20Migration%20Guide%20v6.pdf
- FlightAware Standard licence: https://www.flightaware.com/commercial/aeroapi/AeroAPI_Standard_License.pdf
- AirLabs flight lookup: https://airlabs.co/docs/flight
- AirLabs real-time registration lookup: https://airlabs.co/docs/flights
- AirLabs schedules/limits: https://airlabs.co/docs/schedules
- AirLabs assignment caveats: https://airlabs.co/aircraft-type-by-flight-number
- AirLabs free-package/pricing overview: https://airlabs.co/ and https://airlabs.co/OAG-Airline-Schedules-Database-API
- AirLabs general terms (no sufficiently specific cache/redistribution grant identified): https://airlabs.co/terms-of-service
- Flightradar24 scheduling limitation: https://fr24api.flightradar24.com/docs/faq
- Flightradar24 summaries: https://fr24api.flightradar24.com/docs/endpoints/flight-summary
- Flightradar24 subscriptions: https://fr24api.flightradar24.com/subscriptions-and-credits/
- adsb.lol docs/access: https://api.adsb.lol/docs and https://www.adsb.lol/request
- FlyItalyADSB provider-maintained API repository: https://github.com/flyitalyadsb/adsb-api
- OpenSky current terms: https://opensky-network.org/about/terms-of-use
- OpenSky FAQ/data limitations: https://dev.opensky-network.org/about/faq
