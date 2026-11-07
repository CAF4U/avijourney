import 'search_result.dart';

/// Separates acquired surveillance data from worldwide reference discovery.
/// No scope implies a worldwide live-aircraft or schedule lookup.
enum SearchScope {
  all,
  scanArea,
  worldwideReference;

  bool includes(SearchResultType type) => switch (this) {
        SearchScope.all => true,
        SearchScope.scanArea =>
          type == SearchResultType.aircraft || type == SearchResultType.flight,
        SearchScope.worldwideReference => type == SearchResultType.airport ||
            type == SearchResultType.airline ||
            type == SearchResultType.route,
      };
}
