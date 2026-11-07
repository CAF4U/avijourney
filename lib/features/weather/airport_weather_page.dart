import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../domain/models/airport.dart';
import '../../domain/models/airport_weather.dart';
import '../discovery/detail_widgets.dart';

void openAirportWeather(
        BuildContext context, Airport airport, AppController controller) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            AirportWeatherPage(airport: airport, controller: controller)));

class AirportWeatherPage extends StatefulWidget {
  const AirportWeatherPage(
      {required this.airport, required this.controller, super.key});
  final Airport airport;
  final AppController controller;
  @override
  State<AirportWeatherPage> createState() => _AirportWeatherPageState();
}

class _AirportWeatherPageState extends State<AirportWeatherPage> {
  Timer? _timer;
  bool _enabled = false;
  @override
  void initState() {
    super.initState();
    _enabled = widget.controller.settings.airportWeather;
    widget.controller.addListener(_settingsChanged);
    scheduleMicrotask(_load);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) _load();
    });
  }

  void _settingsChanged() {
    final enabled = widget.controller.settings.airportWeather;
    if (enabled != _enabled) {
      _enabled = enabled;
      if (enabled) scheduleMicrotask(_load);
    }
  }

  void _load({bool force = false}) {
    if (!mounted ||
        !widget.controller.settings.airportWeather ||
        !widget.controller.isActive) return;
    unawaited(
        widget.controller.weather.load(widget.airport.icao, force: force));
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_settingsChanged);
    super.dispose();
  }

  String _time(DateTime? t) =>
      t == null ? 'Unavailable' : '${t.toUtc().toIso8601String()} (UTC)';
  String _number(double? v, String unit) => v == null
      ? 'Unavailable'
      : '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} $unit';
  Map<String, String> _conditions(WeatherConditions c) => {
        if (c.temperatureC != null)
          'Temperature': _number(c.temperatureC, '°C'),
        if (c.dewpointC != null) 'Dew point': _number(c.dewpointC, '°C'),
        'Wind':
            '${c.windDirection == null ? "Direction unspecified" : c.windDirection == "VRB" ? "Variable direction" : "${c.windDirection}°"} · ${_number(c.windSpeedKt, "kt")}${c.windGustKt == null ? "" : " gust ${_number(c.windGustKt, "kt")}"}',
        'Visibility': c.visibilityMiles == null
            ? 'Unspecified; see raw report'
            : '${c.visibilityMiles} statute miles',
        if (c.pressureHpa != null) 'Pressure': _number(c.pressureHpa, 'hPa'),
        'Cloud layers': c.clouds.isEmpty
            ? 'No decoded layers; see raw report'
            : c.clouds
                .map((v) =>
                    '${v.cover} ${v.baseFeet == null ? "base unknown" : "${v.baseFeet!.round()} ft"}')
                .join('\n'),
        if (c.weatherCodes != null) 'Weather codes': c.weatherCodes!,
        if (c.flightCategory != null) 'Reported category': c.flightCategory!,
      };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable:
          Listenable.merge([widget.controller, widget.controller.weather]),
      builder: (context, _) {
        final controller = widget.controller;
        return Scaffold(
            key: const Key('airportWeatherPage'),
            appBar:
                AppBar(title: Text('${widget.airport.displayCode} weather')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              SwitchListTile(
                  key: const Key('airportWeatherCapabilitySwitch'),
                  title: const Text('Airport METAR / TAF weather'),
                  value: controller.settings.airportWeather,
                  onChanged: (v) => controller.updateSettings(
                      controller.settings.copyWith(airportWeather: v))),
              const Text(
                  'Source: NOAA Aviation Weather Center. Availability varies by station. Observations and forecasts are separate; cloud bases are reported above the station.'),
              if (!controller.settings.airportWeather)
                const Text(
                    'Weather capability is off. Enable it to fetch airport observations and forecasts.')
              else ...[
                OutlinedButton.icon(
                    key: const Key('refreshAirportWeather'),
                    onPressed: controller.weather.loading(widget.airport.icao)
                        ? null
                        : () => _load(force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh weather (60-second cooldown)')),
                if (controller.weather.loading(widget.airport.icao))
                  const LinearProgressIndicator(),
                for (final kind in WeatherKind.values) _report(kind),
              ],
            ]));
      });
  Widget _report(WeatherKind kind) {
    final value = widget.controller.weather.reading(widget.airport.icao, kind);
    final r = value?.report;
    final now = DateTime.now().toUtc();
    final stale = r != null &&
        (r.issuedAt == null ||
            (kind == WeatherKind.metar
                ? now.difference(r.issuedAt!) > const Duration(hours: 2)
                : r.validTo == null || now.isAfter(r.validTo!)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text(kind == WeatherKind.metar ? 'METAR · OBSERVATION' : 'TAF · FORECAST',
          style: Theme.of(context).textTheme.titleLarge),
      if (value?.problem != null) Text(value!.problem!),
      if (value?.noReport == true)
        const Text(
            'No current report supplied for this station. A retained older report, if shown, is not current.'),
      if (r == null)
        const Text('No report available yet.')
      else ...[
        Text(
            '${value!.fromCache ? "Cached / retained report" : "Downloaded report"}${stale ? " · STALE / EXPIRED OR TIME UNKNOWN" : ""}'),
        Text('Retrieved ${_time(value.fetchedAt)}'),
        DetailSection(title: '${kind.name.toUpperCase()} TIMES', rows: {
          'Station': r.station,
          'Observation / issue': _time(r.issuedAt),
          if (kind == WeatherKind.taf) 'Valid from': _time(r.validFrom),
          if (kind == WeatherKind.taf) 'Valid to': _time(r.validTo)
        }),
        if (kind == WeatherKind.metar)
          DetailSection(
              title: 'DECODED OBSERVATION', rows: _conditions(r.conditions)),
        if (kind == WeatherKind.taf) ...[
          const Text(
              'Forecast groups may overlap. TEMPO, BECMG and probability groups are conditional, not a single guaranteed timeline. Unspecified fields are not invented or carried forward here.'),
          for (final p in r.periods)
            DetailSection(
                title:
                    '${p.change ?? "BASE FORECAST"}${p.probability == null ? "" : " · ${p.probability}%"}',
                rows: {
                  'From': _time(p.from),
                  'To': _time(p.to),
                  if (p.becomingAt != null) 'Becoming by': _time(p.becomingAt),
                  ..._conditions(p.conditions)
                }),
        ],
        const Text('Original report',
            style: TextStyle(fontWeight: FontWeight.bold)),
        SelectableText(r.raw),
      ],
    ]);
  }
}
