# CAF4U Aircraft Companion V0.3 UX Requirements

## Navigation

Primary portrait navigation: Radar, Map, Cards, Saved. Landscape may adapt placement, but all controls remain inside safe areas.

## Header

Show CAF4U Aircraft Companion identity, development version, feed status and visible-aircraft count. OpenSky is a provider, not the product brand.

## Radar

- Default 20 NM.
- Tap range badge for 20 / 80 / 140 / 200 NM.
- Wider range reduces label density.
- Selected target remains identifiable.
- Trails are observed historical positions only.
- North remains visibly indicated.
- Tapping a target selects it and opens the existing Aircraft Detail surface.

## Search

Use one universal search field with tappable examples. Explain that live
aircraft and flight results come from the current tracking area, while airport
and airline discovery uses the bundled global catalogs. Catalog reference data
must never be presented as schedule or flight-number verification.

## Map

Must behave like a real map application: pinch zoom, pan, geographic marker alignment, selectable aircraft and persistent viewport while switching views.

## Cards

Route example:

```text
LHR                      EXT
London Heathrow          Exeter Airport
        -------->
```

Airport name is secondary but readable. Never invent an IATA code.

## Identity hierarchy

1. verified commercial number;
2. callsign;
3. registration;
4. ICAO24.

If both verified commercial number and callsign exist, show both with commercial number primary.

## Settings

Refresh interval belongs in settings. Suggested choices: 30 seconds, 60 seconds (recommended initial free-use default), 2 minutes, 5 minutes.

## Status language

Connecting, Live, Cached, Offline, Rate limited, Feed error. Cached data should show age when practical.

## Accessibility/readability

Do not rely solely on colour for climb/descent/selection. Use comfortable touch targets, respect text scaling where possible and prevent label clutter from obscuring controls.

### Search hierarchy

Search displays a selectable list first, even for a single result. Category chips narrow the list without applying a display filter. Selecting an airline or route opens its aircraft list, with a back control that preserves the original query and results. Selecting an airport opens Map at that airport and sets its scan centre. Selecting an individual flight or aircraft opens Map at its observed position, with that target selected. An explicit information button retains airport filters and aircraft/flight details. Showing a route on the map and applying a display filter remain explicit actions after selection. Route/airline aircraft lists use acquired data only and explain empty results.


### Location navigation

Changing the scan centre through settings, airport selection, device location or a map point automatically recentres the map, including when Map is inactive. Ordinary feed refreshes do not interrupt manual panning. The radar location footer is a visible tap target offering saved airports and airport search. Location navigation does not wait for live-provider acquisition to finish.
