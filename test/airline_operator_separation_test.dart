import 'package:avijourney/app/app_controller.dart';
import 'package:avijourney/app/discovery/flight_airline_attribution.dart';
import 'package:avijourney/data/local/static_airline_catalog.dart';
import 'package:avijourney/domain/models/aircraft_identity.dart';
import 'package:avijourney/domain/models/aircraft_state.dart';
import 'package:avijourney/domain/models/airline.dart';
import 'package:avijourney/domain/models/flight.dart';
import 'package:avijourney/domain/models/tracked_aircraft.dart';
import 'package:avijourney/domain/repositories/aircraft_repository.dart';
import 'package:avijourney/features/cards/aircraft_cards_view.dart';
import 'package:avijourney/features/aircraft_detail/aircraft_detail_sheet.dart';
import 'package:avijourney/features/flight_detail/flight_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrackedAircraft example({String callsign = 'RYR48ZN', Flight? flight}) =>
    TrackedAircraft(
      state: AircraftState(
          icao24: '4d21ec',
          callsign: callsign,
          latitude: 51.38,
          longitude: -2.72,
          altitudeFeet: 0,
          groundSpeedKnots: 0,
          trackDegrees: 0,
          verticalRateFeetPerMinute: 0,
          observedAt: DateTime.utc(2026, 11, 1)),
      identity: const AircraftIdentity(
          icao24: '4d21ec', registration: '9H-QAD', operatorName: 'Malta Air'),
      flight: flight,
    );

class OneAircraft implements AircraftRepository {
  @override
  Future<List<TrackedAircraft>> loadNearby(
          {required double centerLatitude,
          required double centerLongitude,
          required double radiusNauticalMiles}) async =>
      [example()];
}

void main() {
  test(
      'Ryanair callsign association is distinct from Malta Air operator without fabricating a flight number',
      () {
    final aircraft = example();
    final attribution =
        resolveFlightAirline(aircraft, StaticAirlineCatalog.entries);
    expect(attribution.name, 'Ryanair');
    expect(attribution.fromCallsign, isTrue);
    expect(attribution.basis, contains('marketing carrier unverified'));
    expect(aircraft.identity!.operatorName, 'Malta Air');
    expect(aircraft.primaryIdentifier, 'RYR48ZN');
    expect(aircraft.flight?.commercialFlightNumber, isNull);
  });
  test(
      'reported verified flight airline takes precedence over operational callsign metadata',
      () {
    final aircraft = example(
        flight: const Flight(
            operationalCallsign: 'RYR48ZN',
            airlineName: 'Different Marketing Airline',
            source: 'Verified test provider',
            verificationState: FlightVerificationState.verified));
    final a = resolveFlightAirline(aircraft, StaticAirlineCatalog.entries);
    expect(a.name, 'Different Marketing Airline');
    expect(a.fromCallsign, isFalse);
    expect(a.basis, contains('Verified flight data'));
    expect(aircraft.identity!.operatorName, 'Malta Air');
  });
  test(
      'unknown or ambiguous callsign leaves airline unknown and never substitutes operator',
      () {
    expect(
        resolveFlightAirline(
                example(callsign: '9HQAD'), StaticAirlineCatalog.entries)
            .airline,
        isNull);
    expect(
        resolveFlightAirline(example(), const [
          Airline(name: 'One', icaoCode: 'RYR'),
          Airline(name: 'Two', icaoCode: 'RYR')
        ]).airline,
        isNull);
  });
  testWidgets('cards label and link airline and operator separately on a phone',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final c = AppController(repository: OneAircraft());
    addTearDown(c.dispose);
    await c.refresh();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AircraftCardsView(controller: c))));
    expect(find.text('Airline: Ryanair (callsign)'), findsOneWidget);
    expect(find.text('Operator: Malta Air'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cardAirline-4d21ec')));
    await tester.pumpAndSettle();
    expect(find.text('AIRLINE INFORMATION'), findsOneWidget);
    expect(find.text('RYR'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cardOperator-4d21ec')));
    await tester.pumpAndSettle();
    expect(find.text('OPERATOR INFORMATION'), findsOneWidget);
    expect(find.text('Malta Air'), findsWidgets);
  });
  testWidgets(
      'aircraft and flight details keep both identities and attribution visible',
      (tester) async {
    final c = AppController(repository: OneAircraft());
    addTearDown(c.dispose);
    await c.refresh();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showAircraftDetail(context, example(), c),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Ryanair'), findsOneWidget);
    expect(find.text('Malta Air'), findsOneWidget);
    expect(find.textContaining('marketing carrier unverified'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlightDetailView(
                aircraft: example(), controller: c, onShowOnMap: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Ryanair'), findsOneWidget);
    expect(find.text('Malta Air'), findsOneWidget);
    expect(find.text('Unresolved'), findsOneWidget);
  });
}
