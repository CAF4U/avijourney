import 'dart:typed_data';
import 'package:avijourney/app/discovery/operator_reference_resolver.dart';
import 'package:avijourney/data/local/bundled_airline_search_provider.dart';
import 'package:avijourney/data/local/static_airline_catalog.dart';
import 'package:avijourney/data/local/verified_operator_references.dart';
import 'package:avijourney/domain/models/aircraft_filter.dart';
import 'package:avijourney/domain/models/aircraft_identity.dart';
import 'package:avijourney/domain/models/airline.dart';
import 'package:avijourney/domain/models/tracked_aircraft.dart';
import 'package:avijourney/features/discovery/entity_detail_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'aircraft_map_view_test.dart' as fixtures;

class BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw StateError('missing asset');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'offline references resolve FedEx aliases with codes, country and provenance',
      () async {
    final provider = BundledAirlineSearchProvider();
    await provider.initialize();
    expect(provider.operatorReferences.length, greaterThan(3000));
    for (final name in [
      'FedEx Express',
      'Federal Express',
      'FEDERAL EXPRESS CORPORATION'
    ]) {
      final result =
          resolveOperatorReference(name, provider.operatorReferences);
      expect(result.name, 'FedEx Express');
      expect(result.iataCode, 'FX');
      expect(result.icaoCode, 'FDX');
      expect(result.country, 'United States');
      expect(result.source, contains('IATA and FAA'));
      expect(
          result.sourceUrls,
          contains(
              'https://www.iata.org/en/about/members/airline-list/fedex-express/84/'));
      if (name == 'FedEx Express') {
        expect(result.sourceUrls,
            contains('https://www.wikidata.org/wiki/Q782557'));
      }
      expect(result.referenceDate, contains('2026-11-01'));
    }
    expect(provider.search('Federal Express').single.icaoCode, 'FDX');
    expect(provider.airlines.where((a) => a.icaoCode == 'FDX'), hasLength(1));
  });
  test('asset failure retains independently checked operator data', () async {
    final provider = BundledAirlineSearchProvider(bundle: BrokenBundle());
    await provider.initialize();
    expect(
        resolveOperatorReference('Federal Express', provider.operatorReferences)
            .country,
        'United States');
    expect(
        const StaticAirlineCatalog().search('Federal Express').single.icaoCode,
        'FDX');
  });
  test(
      'ambiguous names, code aliases and partial operator names never manufacture identity',
      () {
    const shared = [
      Airline(
          name: 'First',
          aliases: ['Shared'],
          icaoCode: 'AAA',
          iataCode: 'AA',
          country: 'A'),
      Airline(
          name: 'Second',
          aliases: ['Shared'],
          icaoCode: 'BBB',
          iataCode: 'BB',
          country: 'B')
    ];
    final unknown = resolveOperatorReference('Shared', shared);
    expect(unknown.icaoCode, isNull);
    expect(unknown.source, contains('Ambiguous'));
    for (final name in ['FX', 'FDX', 'Federal', 'FedEx Express Holdings XYZ']) {
      expect(
          resolveOperatorReference(name, verifiedOperatorReferences).icaoCode,
          isNull);
    }
    expect(
        resolveOperatorReference('FX', const [
          Airline(name: 'Cargo Example', aliases: ['FX'], icaoCode: 'XYZ')
        ]).icaoCode,
        isNull);
  });
  test(
      'verified operator aliases match observed owner names without a commercial flight identity',
      () async {
    final c = fixtures.createController();
    addTearDown(c.dispose);
    await c.refresh();
    final original = c.aircraft.first;
    final tracked = TrackedAircraft(
        state: original.state,
        identity: const AircraftIdentity(
            icao24: '40621D', operatorName: 'Federal Express'));
    expect(
        AircraftFilter(
                label: 'FedEx', airline: verifiedOperatorReferences.single)
            .matches(tracked, matchesQuery: false),
        isTrue);
    expect(tracked.flight?.commercialFlightNumber, isNull);
  });
  testWidgets(
      'operator card displays restored fields and reference date offline',
      (tester) async {
    final c = fixtures.createController();
    addTearDown(c.dispose);
    await c.refresh();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        openOperatorDetails(context, 'Federal Express', c),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('FX'), findsOneWidget);
    expect(find.text('FDX'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('2026-11-01'), findsOneWidget);
  });
}
