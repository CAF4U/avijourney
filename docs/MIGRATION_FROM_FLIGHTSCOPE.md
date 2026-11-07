# Migration from FlightScope V0.2.5

## Why V0.2.5 is frozen

The Tauri prototype answered the main feasibility questions: APK delivery, useful mobile radar UI, live OpenSky data, HexDB enrichment, cards/detail, filters and enough real-device testing to define a clean Flutter rebuild.

Reference repository: `Hugo-Doswald/flightscope-prototype`  
Reference live-data commit: `82729ea`

## Preserve

- dark aviation/radar visual language;
- Radar / Map / Cards / Saved mental model;
- 20 NM local default;
- range-dependent radar label density;
- selected-aircraft emphasis;
- observed trails;
- route and aircraft metrics on cards;
- aircraft detail;
- filters;
- OpenSky + HexDB free-first concept;
- provider failures shown in UI rather than blanking the app.

## Improve

- Replace static pseudo-map with real geographic mapping.
- Add airport names below codes.
- Expose refresh interval in settings.
- Make radar range badge interactive.
- Persist saved aircraft and useful caches.
- Separate domain/data/presentation architecture.

## Do not reproduce prototype mistakes

- no names that shadow language/core types;
- no startup network request capable of preventing shell rendering;
- no fabricated trails;
- no static pseudo-map;
- no portrait-fixed layout in landscape;
- no unbounded polling;
- no guessed flight numbers.

## Naming

FlightScope was a prototype name and collides with an established brand. The Flutter application is **CAF4U Aircraft Companion**.
