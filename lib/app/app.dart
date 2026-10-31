import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/theme/app_theme.dart';
import '../domain/models/app_settings.dart';
import '../data/hexdb/hexdb_aircraft_enrichment_provider.dart';
import '../data/local/shared_preferences_app_store.dart';
import '../data/local/bundled_airport_search_provider.dart';
import '../data/local/bundled_airline_search_provider.dart';
import '../data/local/static_airport_search_provider.dart';
import '../data/local/static_airline_catalog.dart';
import '../data/location/geolocator_device_location_provider.dart';
import '../data/mapping/open_street_map_tile_source.dart';
import '../data/mock/mock_aircraft_provider.dart';
import '../data/mock/mock_enrichment_provider.dart';
import '../data/opensky/opensky_aircraft_position_provider.dart';
import '../domain/providers/flight_identity_provider.dart';
import '../data/repositories/live_aircraft_repository.dart';
import '../data/repositories/mock_aircraft_repository.dart';
import '../features/home/home_shell.dart';
import 'app_controller.dart';
import 'mapping/map_viewport_controller.dart';

class AviJourneyApp extends StatefulWidget {
  const AviJourneyApp({
    super.key,
    this.controller,
    this.mapViewportController,
    this.showMapTiles = true,
    this.useLiveData = true,
  });

  final AppController? controller;
  final MapViewportController? mapViewportController;
  final bool showMapTiles;
  final bool useLiveData;

  @override
  State<AviJourneyApp> createState() => _AviJourneyAppState();
}

class _AviJourneyAppState extends State<AviJourneyApp>
    with WidgetsBindingObserver {
  http.Client? _httpClient;
  late final AppController controller = widget.controller ?? _buildController();
  late final MapViewportController mapViewportController =
      widget.mapViewportController ??
          MapViewportController(MapViewport.around(controller.trackingCenter));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  AppController _buildController() {
    if (!widget.useLiveData) {
      return AppController(
        repository: MockAircraftRepository(
          positions: const MockAircraftPositionProvider(),
          enrichment: const MockAircraftEnrichmentProvider(),
        ),
        airportSearchProvider: const StaticAirportSearchProvider(),
        airlineSearchProvider: const StaticAirlineCatalog(),
        feedName: 'Mock feed',
      );
    }
    final client = http.Client();
    _httpClient = client;
    return AppController(
      repository: LiveAircraftRepository(
        positions: OpenSkyAircraftPositionProvider(client: client),
        enrichment: HexDbAircraftEnrichmentProvider(client: client),
        flightIdentity: CachedFlightIdentityProvider(
          const NoOpFlightIdentityProvider(),
        ),
      ),
      preferencesStore: const SharedPreferencesAppStore(),
      deviceLocationProvider: const GeolocatorDeviceLocationProvider(),
      airportSearchProvider: BundledAirportSearchProvider(),
      airlineSearchProvider: BundledAirlineSearchProvider(),
      feedName: 'OpenSky + HexDB',
    );
  }

  Future<void> _initialize() async {
    await controller.initialize();
    if (widget.mapViewportController == null) {
      mapViewportController
          .update(MapViewport.around(controller.trackingCenter));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.resume();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) controller.dispose();
    if (widget.mapViewportController == null) mapViewportController.dispose();
    _httpClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
              title: 'CAF4U Aircraft Companion',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: controller.settings.appearance == AppAppearance.light
                  ? ThemeMode.light
                  : ThemeMode.dark,
              home: HomeShell(
                controller: controller,
                mapViewportController: mapViewportController,
                mapTileSource: const OpenStreetMapTileSource(),
                showMapTiles: widget.showMapTiles,
              ),
            ));
  }
}
