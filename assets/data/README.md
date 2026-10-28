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
