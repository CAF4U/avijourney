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


### Linked information cards (V0.3.7)

Aircraft section headings, model/type and registration open the physical aircraft profile. Operator values open airline/operator profiles, with catalogue codes and country only for an exact name match. Airport values open dedicated airport pages with reference information, map/scan navigation, followed state, observed arrivals/departures, ground aircraft within 3 NM and local flight search. These are acquired-data lists, not complete scheduled airport boards; missing schedules, gates and statuses stay unavailable. Route headings navigate to the existing geographic map and fit the airport connection, which remains distinguished from an actual flight track. Back returns to the originating detail card.


### Radar zoom (V0.4.1)

Pinch apart/together or use +/− to zoom around the scan centre, down to a 0.25 NM displayed radius. Aircraft markers, label fonts and tap tolerance stay the same screen size while geographical spacing increases. The VIEW scale shows the displayed radius; the existing range badge controls acquisition coverage. Zoom is presentation only: it never changes scan range, alert area or provider cadence. Reset restores the full scan area. Feed refreshes and tab changes preserve zoom; a new scan centre or range restores the full area. Radar targets/trails are clipped to the scope and tap selection uses the zoomed positions.


### View navigation and manual refresh (V0.4.2)

Zoomed radar supports one-finger pan and focal-point pinch zoom. Panning is limited to the acquired scan circle; it changes presentation only. Reset and new scan locations/ranges restore the full scope. Pan/zoom survive normal feed refreshes. Map panning more than 100 m from the scan centre offers a central crosshair and explicit Track here button; selecting it updates the tracking centre and requests aircraft for that area while retaining map zoom. Panning alone makes no requests.

Radar, Map and Live Metrics have shared manual aircraft refresh controls with a ten-second minimum between manual request starts. All controls show busy/countdown states, deduplicate concurrent requests and retain cooldown after failures. Automatic polling retains its minimum 30-second interval; a manual refresh restarts that schedule. Existing provider failures and cached-data states remain visible. Live detail cards listen to controller updates and show last-known data honestly when an aircraft disappears from the snapshot.


### Compact route map presentation (V0.4.3)

Route airports use small hollow position dots with translucent code labels offset below and to either side. Aircraft use small heading-oriented symbols, a light selection outline and translucent callsign labels offset above/right. Symbols remain centred on the actual coordinates; visual reduction retains a 44-pixel aircraft tap target. Route fitting reserves space for map controls and offset labels.

On Map, a compact translucent route strip replaces the large route information box and duplicate filter footer. It identifies the connection and current-area count, expands on tap to explain coverage and distinguish the connection from the actual track, and retains a clear-filter action. Other views retain their existing filter footer.
