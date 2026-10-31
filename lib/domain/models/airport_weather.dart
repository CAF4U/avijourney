enum WeatherKind { metar, taf }

class WeatherConditions {
  const WeatherConditions(
      {this.temperatureC,
      this.dewpointC,
      this.windDirection,
      this.windSpeedKt,
      this.windGustKt,
      this.visibilityMiles,
      this.pressureHpa,
      this.weatherCodes,
      this.clouds = const [],
      this.flightCategory});
  final double? temperatureC, dewpointC, windSpeedKt, windGustKt, pressureHpa;
  final String? windDirection, visibilityMiles, weatherCodes, flightCategory;
  final List<WeatherCloud> clouds;
}

class WeatherCloud {
  const WeatherCloud(this.cover, this.baseFeet);
  final String cover;
  final double? baseFeet;
}

class ForecastPeriod {
  const ForecastPeriod(
      {this.from,
      this.to,
      this.becomingAt,
      this.change,
      this.probability,
      required this.conditions});
  final DateTime? from, to, becomingAt;
  final String? change;
  final int? probability;
  final WeatherConditions conditions;
}

class AirportWeatherReport {
  const AirportWeatherReport(
      {required this.station,
      required this.kind,
      required this.raw,
      this.issuedAt,
      this.validFrom,
      this.validTo,
      required this.conditions,
      this.periods = const []});
  final String station, raw;
  final WeatherKind kind;
  final DateTime? issuedAt, validFrom, validTo;
  final WeatherConditions conditions;
  final List<ForecastPeriod> periods;
}

class WeatherReading {
  const WeatherReading(
      {this.report,
      this.fetchedAt,
      required this.checkedAt,
      this.fromCache = false,
      this.problem,
      this.noReport = false});
  final AirportWeatherReport? report;
  final DateTime? fetchedAt;
  final DateTime checkedAt;
  final bool fromCache, noReport;
  final String? problem;
}
