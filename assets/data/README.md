# Discovery catalog sources

`global_airports.tsv` is a build-time subset of scheduled-service airports from
[OurAirports](https://ourairports.com/data/), downloaded on 28 October 2026.
OurAirports releases the dataset to the Public Domain with no warranty. The
subset retains airports with IATA codes and coordinates and is not navigation
data.

`global_airlines.tsv` is a build-time subset of active-coded entries from the
[OpenFlights airline database](https://openflights.org/data.php), downloaded on
28 October 2026. OpenFlights distributes its database under the Open Database
License (ODbL) and Database Contents License. The upstream `active` flag is
explicitly documented as imperfect, so discovery results are reference data,
not proof that an airline currently operates.

AviJourney acknowledges both sources in the search UI and does not use either
catalog to fabricate flight-number mappings.

## Operator references (V0.4.4)

`operator_references.json` is a separate CC0 Wikidata snapshot downloaded on
1 November 2026. It holds 3,407 operator entities with an unambiguous, valid ICAO
code, English label, available country/IATA fields and English aliases. Missing
or conflicting source values stay null. Each entry retains its Wikidata URL,
source and snapshot date. This includes historical entities and is enrichment
reference data, not a list of currently operating airlines. It is not added
wholesale to the active-airline discovery list.

Regenerate it using `tool/build_operator_references.py`, which documents the
two SPARQL queries and accepts their JSON exports. No Wikidata/API requests
run on the phone. The snapshots are structured data released under CC0:
https://www.wikidata.org/wiki/Wikidata:Licensing

`verified_operator_references.dart` contains independently checked overrides
usable even if catalogue assets fail. FedEx Express is FX / FDX / United States
with explicit legal/known-name aliases, checked against the IATA member
directory and FAA company-designator table on 1 November 2026. These are
individual checked facts, not a bulk copy or API integration with IATA/FAA.
The OpenFlights inactive flag incorrectly excluded this operator; the override
restores it without blindly including all historical/inactive carriers.

Operator resolution uses exact normalized names or explicit aliases. Code-only
aliases, partial/fuzzy names, callsign-to-flight-number transformations and
IATA-only identity matching are not used. Conflicting codes/countries leave
the operator unresolved. Record sources/dates are visible on operator cards.
OpenFlights data remains separately attributed under its existing licence.
