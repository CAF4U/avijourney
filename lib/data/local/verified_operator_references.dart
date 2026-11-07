import '../../domain/models/airline.dart';

/// Independently checked overrides. Keep these usable if assets fail to load.
const verifiedOperatorReferences = <Airline>[
  Airline(
      name: 'FedEx Express',
      iataCode: 'FX',
      icaoCode: 'FDX',
      country: 'United States',
      aliases: [
        'Federal Express',
        'Federal Express Corporation',
        'Federal Express Corporation dba FedEx Express'
      ],
      source: 'Independently checked operator reference: IATA and FAA',
      sourceUrls: [
        'https://www.iata.org/en/about/members/airline-list/fedex-express/84/',
        'https://www.faa.gov/air_traffic/publications/atpubs/cnt_html/chap3_section_1.html'
      ],
      referenceDate: '2026-11-01'),
];
