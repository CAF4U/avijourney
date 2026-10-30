import 'package:avijourney/data/local/bundled_airport_search_provider.dart';
import 'package:avijourney/data/local/bundled_airline_search_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled discovery catalog covers airports across world regions',
      () async {
    final provider = BundledAirportSearchProvider();
    await provider.initialize();

    expect(provider.airportCount, greaterThan(3000));
    expect(provider.search('La Guardia').single.icao, 'KLGA');
    expect(provider.search('LaGuardia').single.icao, 'KLGA');
    expect(provider.search('JFK').firstWhere((a) => a.iata == 'JFK').name,
        contains('Kennedy'));
    expect(provider.search('DXB').firstWhere((a) => a.iata == 'DXB').city,
        'Dubai');
    expect(provider.search('SYD').firstWhere((a) => a.iata == 'SYD').country,
        'AU');
  });

  test('airline discovery is independent of nearby live aircraft', () async {
    final provider = BundledAirlineSearchProvider();
    await provider.initialize();
    expect(provider.airlines.length, greaterThan(1000));
    expect(
      provider.search('Singapore Airlines'),
      isNotEmpty,
    );
    expect(
      provider.search('ETH').where((airline) => airline.icaoCode == 'ETH'),
      isNotEmpty,
    );
  });
}
