"""Build a standalone CC0 snapshot from Wikidata SPARQL result exports.

Primary query:
SELECT ?item ?itemLabel ?icao ?iata ?countryLabel WHERE {
  ?item wdt:P230 ?icao. OPTIONAL { ?item wdt:P229 ?iata. }
  OPTIONAL { ?item wdt:P17 ?country. }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
Aliases query:
SELECT ?item ?alias WHERE { ?item wdt:P230 ?icao; skos:altLabel ?alias.
  FILTER(LANG(?alias)="en") }

Download via https://query.wikidata.org/sparql with format=json and a custom
User-Agent. This is maintenance work, never an app runtime request. Historical
records are reference information, not evidence of current operating status.
"""
import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--records', required=True)
parser.add_argument('--aliases', required=True)
parser.add_argument('--date', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
groups = {}
for row in json.loads(Path(args.records).read_text())['results']['bindings']:
    entity = row['item']['value'].rsplit('/', 1)[-1]
    group = groups.setdefault(entity, {k: set() for k in ['name', 'icao', 'iata', 'country', 'aliases']})
    for key, source in [('name', 'itemLabel'), ('icao', 'icao'), ('iata', 'iata'), ('country', 'countryLabel')]:
        if source in row:
            group[key].add(row[source]['value'])
for row in json.loads(Path(args.aliases).read_text())['results']['bindings']:
    entity = row['item']['value'].rsplit('/', 1)[-1]
    if entity in groups:
        groups[entity]['aliases'].add(row['alias']['value'])

def single(values, pattern=None):
    valid = {v for v in values if pattern is None or re.fullmatch(pattern, v)}
    return next(iter(valid)) if len(valid) == 1 else None

records = []
for entity, group in sorted(groups.items()):
    name = single(group['name'])
    icao = single(group['icao'], r'[A-Z]{3}')
    if not name or name == entity or not icao:
        continue
    records.append(dict(name=name, icao=icao,
        iata=single(group['iata'], r'[A-Z0-9]{2}'),
        country=single(group['country']), aliases=sorted(group['aliases']),
        source='Wikidata (CC0; community reference)',
        urls=[f'https://www.wikidata.org/wiki/{entity}'], date=args.date))
Path(args.output).write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
print(f'{len(records)} operator references written')
