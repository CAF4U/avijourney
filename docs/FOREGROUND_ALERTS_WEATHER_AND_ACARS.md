# Foreground alerts, airport weather and OOOI research

V0.4.0, 31 October 2026. Two independent capabilities, both opt-in and persisted locally.

## Foreground alerts

Only successful foreground acquisitions are processed. Surveillance position timestamps are distinct from last contact; stale (>90 s), future (>15 s), missing-time and out-of-order samples are ignored. Detector baselines reset after centre/range/rule/follow changes, suspension and feed failure. Filters do not change the scan area. Detection uses a geographic circle, not the provider bounding box. Existing followed targets establish the initial baseline; later new detections can alert. Brief missing coverage never establishes a geographic exit. Per-aircraft/event cooldown: 10 minutes. Local history: latest 50 events. No backend, background service or notification-tray delivery. Optional system click/haptic feedback is device-dependent.

7600/7700 labels describe feed-reported codes, not independent emergency verification. Aircraft may have stale/missing code fields. Entry wording is `detected in tracking area`, not an exact boundary crossing.

## Movement inference

Ground flags, fresh position times and observation history are primary. Two unique, consecutive samples of a changed ground flag (within a three-minute observation gap) establish an estimated takeoff or landing transition. A missing ground flag or a longer gap restarts evidence. No event timestamp is asserted to be an exact wheels-on/off time. Current phases are explicitly estimated: stationary on ground, moving on ground / possible taxi, high-speed ground movement, airborne. Missing speed does not imply stationary. Altitude zero is not a gate/ground detector: airports may be elevated, barometric/geometric references differ and data can be missing. OUT/pushback and IN/gate arrival cannot be established without door/brake/gate data. No OOOI events are fabricated.

## METAR and TAF

Provider abstraction isolates AWC JSON in the data layer. Native Android HTTPS requests use the four-character station identifier and a custom User-Agent. Requests are serialized and spaced by at least one second; 429 responses establish global backoff. METAR/TAF caches use 10/30 minute TTLs, a 60-second manual refresh cooldown and two-minute negative/error retry delay. Up to 60 report records are retained locally. Last usable reports remain visible on failure with timestamps and cache/error labels. 204/no-report responses are distinct from errors. Disabling weather prevents new loads and discards in-flight presentation updates; acquisition stops between METAR and TAF if disabled/suspended. Weather pages check TTLs once a minute only while current and foreground.

Observation time and retrieval time are shown separately. METAR older than two hours is labelled stale; expired or undated TAF is labelled accordingly. Provider visibility is displayed in statute miles, wind in knots, pressure in hPa, cloud base in feet. Raw reports remain available. Conditional TEMPO/BECMG/probability periods retain their type, timing and probability; unspecified fields are not invented or flattened into guaranteed conditions.

AWC documentation: https://aviationweather.gov/data/api/

## ACARS / OOOI access research

Airframes documents ACARS/OOOI endpoints. Its overview says API keys are required but also describes anonymous public endpoints; authentication and pricing pages describe free access for qualifying feeders, for personal/non-commercial use. Licensing states commercial use beyond the access tier requires arrangement, and the API/terms are still being finalized. Therefore a stable, licensed, anonymous free OOOI feed suitable for CAF4U distribution was NOT verified; no Airframes endpoint or secret is embedded and no account is created. The initial alert capability works without ACARS.

References checked 31 October 2026:
- https://docs.airframes.io/api/
- https://docs.airframes.io/api/authentication/
- https://docs.airframes.io/api/pricing/
- https://docs.airframes.io/api/licensing/

A later provider contract must identify aircraft/operational flight, event type, reported event timestamp, reception timestamp, provider/message provenance and correlation confidence. Provider-reported OOOI and ADS-B-derived estimates must remain separate. OOOI trigger logic can vary by aircraft/operator; raw communications coverage is incomplete. API rights, redistribution/caching, access tiers and protected credentials must be resolved before integration.
