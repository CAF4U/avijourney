# AGENTS.md — CAF4U Aircraft Companion

This repository is the clean Flutter/Dart successor to the FlightScope Tauri prototype.

## Read first

1. `docs/V0.3_IMPLEMENTATION_BRIEF.md`
2. `docs/ACCEPTANCE_CRITERIA.md`
3. `docs/UX_REQUIREMENTS.md`
4. `docs/ARCHITECTURE.md`
5. `docs/DATA_PROVIDERS.md`
6. `docs/MIGRATION_FROM_FLIGHTSCOPE.md`

The old `Hugo-Doswald/flightscope-prototype` repository is a visual/behavioural reference only. Do not copy its JavaScript architecture into Flutter.

## Non-negotiable rules

- Build native Flutter/Dart architecture, not a web wrapper.
- Keep data providers behind domain interfaces.
- Never guess or synthesize a commercial flight number.
- Do not hard-wire OpenSky, HexDB or a map tile provider into widgets.
- Real map geometry must use actual latitude/longitude.
- Radar and map consume the same aircraft-state model.
- Provider failure must never blank the application.
- Cache external lookups and expose cached/stale state honestly.
- Prefer free/open data sources; paid APIs may be optional later.
- Do not expand V0.3 into fare search or trip planning before the live-aircraft MVP is stable.

## Working style

- Keep commits small and descriptive.
- Add/update tests with domain/data changes.
- Run `dart format .`, `flutter analyze` and `flutter test` before completing a task.
- Add dependencies only when they materially improve the solution.
- Avoid network calls inside widget `build()` methods.

## Initial milestone

A compilable Android Flutter application with Radar, Map, Cards and Saved navigation, mock aircraft data behind provider interfaces, filters/settings state and a quick radar-range selector.
