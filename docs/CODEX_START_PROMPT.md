# Codex Start Prompt

You are implementing **CAF4U Aircraft Companion V0.3**, a clean Flutter/Dart rebuild of the proven Tauri aircraft-tracking prototype in `Hugo-Doswald/flightscope-prototype`.

Read in order:

1. `AGENTS.md`
2. `docs/V0.3_IMPLEMENTATION_BRIEF.md`
3. `docs/ACCEPTANCE_CRITERIA.md`
4. `docs/UX_REQUIREMENTS.md`
5. `docs/ARCHITECTURE.md`
6. `docs/DATA_PROVIDERS.md`
7. `docs/MIGRATION_FROM_FLIGHTSCOPE.md`

Do not port the old JavaScript architecture.

## First task

Create/complete the standard Flutter project shell for Android first while preserving the supplied docs and Dart sources.

Then implement Milestone 1:

- app theme;
- responsive application shell;
- Radar, Map, Cards and Saved navigation;
- placeholder screens backed by mock `AircraftState` data;
- domain models and provider interfaces;
- selected-aircraft state;
- filters/settings model including radar range and refresh interval;
- quick radar-range selector;
- basic unit/widget tests.

Do **not** connect OpenSky or HexDB in the first commit. Establish architecture and UI/navigation first.

Run `dart format .`, `flutter analyze` and `flutter test` before committing.

Important: never guess commercial flight numbers, never allow a provider failure to block shell rendering, never use a static pseudo-map, and never put network calls in widget `build()` methods.
