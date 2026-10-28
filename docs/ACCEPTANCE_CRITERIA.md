# AviJourney V0.3 Acceptance Criteria

V0.3 is complete only when the critical criteria pass on a real Android device.

## App shell

- [ ] App launches visibly without network connectivity.
- [ ] Provider errors cannot produce a black/blank application.
- [ ] Radar, Map, Cards and Saved navigation works.
- [ ] Portrait and landscape stay inside safe areas.
- [ ] Rotation performs responsive relayout.

## Live data

- [ ] OpenSky returns real geographically bounded states.
- [ ] Refresh is centrally controlled, not widget-driven.
- [ ] Refresh interval is documented and configurable.
- [ ] Last valid snapshot survives temporary provider failure.
- [ ] Rate-limited/offline/error states are visible.

## Radar

- [ ] Geographic radar positioning is correct.
- [ ] 20 NM default is usable.
- [ ] Tap range indicator for 20 / 80 / 140 / 200 NM.
- [ ] Wider ranges reduce clutter.
- [ ] Trails contain observed positions only.
- [ ] North is visibly indicated.
- [ ] Tapping an aircraft target opens Aircraft Detail.

## Map

- [ ] Real geographic map, not static decoration.
- [ ] Pinch zoom and pan work.
- [ ] Aircraft remain geolocated while zooming/panning.
- [ ] Aircraft markers are selectable.
- [ ] Required attribution is visible.

## Enrichment

- [ ] HexDB enrichment is cached.
- [ ] Registration/type/operator appear when available.
- [ ] Origin/destination only appear when verified.
- [ ] Airport code has airport name underneath when available.
- [ ] Missing enrichment never hides live aircraft.

## Identity integrity

- [ ] No guessed commercial flight number.
- [ ] Callsign stays primary when unresolved.
- [ ] Future flight identity supports provenance/verification.

## Interaction

- [ ] Cards/detail scroll naturally.
- [ ] Search and altitude filters work.
- [ ] Trails/labels/saved-only controls work.
- [ ] Saved aircraft survive restart.
- [ ] Search guidance includes tappable examples.
- [ ] Airport and airline discovery is global and independent of radar range.
- [ ] Live aircraft/flight results remain limited to acquired live state.

## Quality gates

- [ ] `dart format .` clean.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] Domain/provider interfaces have tests.
- [ ] README setup works from clean clone.
