# CAF4U Aircraft Companion

**Live aviation around you.**  
*A CAF4U Companion*

CAF4U Aircraft Companion is a standalone aircraft-tracking and aviation discovery companion. V0.3 begins with live aircraft discovery — radar, real geographic maps, aircraft identity, routes, cards, trails, filters and saved aircraft — with airport and airline discovery. Trip itineraries and booking management belong to the separate CAF4U Travel Companion.

## Status

**V0.3.0 — Aircraft discovery and interactive search development build**

The working Tauri proof of concept remains in `Hugo-Doswald/flightscope-prototype`. Its V0.2.5 build proved the core experience on Android using live OpenSky positions and HexDB enrichment. This repository is a clean Flutter/Dart rebuild, not a line-by-line port.

## Product principles

- Live aviation first.
- Never invent flight identity; if a commercial number cannot be verified, show the callsign.
- Keep OpenSky, HexDB, mapping and future schedule sources behind replaceable interfaces.
- Prefer free/open data and cache aggressively.
- Use real geographic maps and real latitude/longitude.
- Treat mobile safe areas, rotation, lifecycle and offline/error states as first-class requirements.
- Remain independently usable from CAF4U Travel Companion.

## V0.3 MVP

- Live radar centred on a chosen location.
- Real geographic map with live aircraft markers.
- Aircraft cards and aircraft detail.
- OpenSky live state vectors.
- HexDB aircraft/operator/route enrichment.
- Airport IATA code plus airport name.
- Search, altitude filters, trails, labels and saved aircraft.
- Configurable radar range and refresh interval.
- Quick range selector by tapping the radar range badge.
- Persistent local cache and saved state.
- Portrait and landscape layouts.
- Explicit connecting, live, cached, offline, rate-limited and provider-error states.

Commercial flight-number resolution is a separate future provider. Callsign-to-flight-number guessing is prohibited.

## Run locally

Install a current Flutter SDK with Android tooling, then run:

```sh
flutter pub get
flutter run
```

Milestone 3 uses geographically bounded OpenSky state vectors and cached HexDB enrichment through replaceable domain providers. Radar and the interactive `flutter_map` map share the same user-selectable tracking centre. Small settings, the selected centre and saved aircraft are stored locally with `shared_preferences`.

Tracking can be centred on the device's foreground location, a locally indexed airport, or a long-pressed map point. Android location permission is requested only when **Use my location** is selected; CAF4U Aircraft Companion does not request background location access.

Pushes to `main` run formatting, analysis and tests, build an Android debug APK, and publish it as the `CAF4U-Aircraft-Companion-v0.3-debug-APK` workflow artifact.

## Documentation

- `docs/PRODUCT_VISION.md`
- `docs/V0.3_IMPLEMENTATION_BRIEF.md`
- `docs/ARCHITECTURE.md`
- `docs/UX_REQUIREMENTS.md`
- `docs/DATA_PROVIDERS.md`
- `docs/MIGRATION_FROM_FLIGHTSCOPE.md`
- `docs/ACCEPTANCE_CRITERIA.md`
- `docs/CODEX_START_PROMPT.md`
- `AGENTS.md`

## Interactive search

Tap aircraft or flight results for details. Tap an airport, airline or route for reference details and actions. Each result has a filter action; the full submitted query can also filter radar, map and cards. Airport filters distinguish origin, destination and either direction. Active filters remain visible and can be cleared. They operate on the current acquired area and update as new snapshots arrive; they do not request worldwide tracking.

Select **Track around this airport** in airport details to change both the acquisition centre and map viewport, staying on the current radar/map tab. This clears the prior search filter. Search accepts both `La Guardia` and `LaGuardia`. Unknown routes never match an airport filter.

The product name is CAF4U Aircraft Companion (formerly AviJourney). The repository slug, Dart package and Android application ID remain stable to preserve installed preferences and follows.

## Appearance and route views (0.3.1)

Settings → Appearance offers Dark and Light; the choice persists across restarts. Radar, map tiles, labels and the app surfaces follow that choice. Existing installations default to Dark.

Enter airport pairs such as `LHR-LAX`, `LHR -> LAX` or `LHR → LAX`. The app resolves known airport codes even without a matching nearby aircraft, then offers **List aircraft on this route** or **Show route and aircraft on map**. Direction matters. The map fits and labels both airports and displays matching acquired aircraft, with a reference connection line (not a verified flight path). Airport pairs do not confirm a scheduled service. Aircraft are still limited to the current tracking area and known provider route data; zero matches is stated explicitly. Clearing the filter removes the connection overlay.

## Search navigation (0.3.2)

Search always shows a result list, including a single matching route. Category chips select flights, aircraft, airlines, routes or airports. Selecting a route/airline/airport opens its detail list inside search; matching aircraft can then be selected for individual details. Back returns to the original results and query. Search alone never changes the display filter. Map, track and filter actions are explicit. The airport/route reference and acquired-area limitations still apply.

## Independent screen appearance (0.3.3)

Radar and Map each have their own on-screen Dark/Light selector. A black-and-green radar can be combined with a light map, independently of the app shell. Both overrides persist across restart. Existing preferences retain their previous global appearance until a screen override is selected; unrelated settings updates preserve both overrides. Reset settings removes the overrides.


V0.3.4 makes scan-centre changes recenter the map automatically. Airport and individual aircraft/flight search rows open Map at the selected location; their information buttons retain details and airport filters. Tap the radar location footer for saved airports or airport search. Live aircraft discovery remains limited to acquired positions.
