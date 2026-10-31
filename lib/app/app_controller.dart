import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/provider_exception.dart';
import '../domain/models/airport.dart';
import '../domain/models/aircraft_filter.dart';
import '../domain/models/aircraft_route.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/tracked_aircraft.dart';
import '../domain/models/followed_item.dart';
import '../domain/models/search_result.dart';
import '../data/local/static_airline_catalog.dart';
import 'search/universal_search_service.dart';
import '../domain/models/tracking_center.dart';
import '../domain/providers/airport_search_provider.dart';
import '../domain/providers/airline_search_provider.dart';
import '../domain/providers/device_location_provider.dart';
import '../domain/repositories/aircraft_repository.dart';
import 'persistence/app_preferences_store.dart';

enum FeedStatus { connecting, live, cached, offline, rateLimited, error }

class AppController extends ChangeNotifier {
  AppController({
    required AircraftRepository repository,
    TrackingCenter trackingCenter = TrackingCenter.heathrow,
    AppPreferencesStore preferencesStore = const NoOpAppPreferencesStore(),
    DeviceLocationProvider? deviceLocationProvider,
    AirportSearchProvider? airportSearchProvider,
    AirlineSearchProvider airlineSearchProvider = const StaticAirlineCatalog(),
    this.feedName = 'OpenSky',
    UniversalSearchService searchService = const UniversalSearchService(),
  })  : _repository = repository,
        _trackingCenter = trackingCenter,
        _preferencesStore = preferencesStore,
        _deviceLocationProvider = deviceLocationProvider,
        _airportSearchProvider = airportSearchProvider,
        _airlineSearchProvider = airlineSearchProvider,
        _searchService = searchService;

  static const minimumRefreshInterval = Duration(seconds: 30);
  final AircraftRepository _repository;
  final AppPreferencesStore _preferencesStore;
  final DeviceLocationProvider? _deviceLocationProvider;
  final AirportSearchProvider? _airportSearchProvider;
  final AirlineSearchProvider _airlineSearchProvider;
  final UniversalSearchService _searchService;
  final String feedName;
  TrackingCenter _trackingCenter;
  List<TrackedAircraft> _aircraft = const [];
  AppSettings _settings = const AppSettings();
  FeedStatus _feedStatus = FeedStatus.connecting;
  String? _selectedIcao24;
  final Set<String> _saved = <String>{};
  final Set<FollowedItem> _followedItems = <FollowedItem>{};
  Timer? _refreshTimer;
  Future<void>? _activeRefresh;
  Duration? _scheduledRefreshInterval;
  bool _isActive = true;
  bool _isChoosingCenterOnMap = false;
  String? _locationMessage;

  List<TrackedAircraft> get aircraft => List.unmodifiable(_aircraft);
  AppSettings get settings => _settings;
  TrackingCenter get trackingCenter => _trackingCenter;
  FeedStatus get feedStatus => _feedStatus;
  String? get selectedIcao24 => _selectedIcao24;
  Set<String> get saved => Set.unmodifiable(_saved);
  Set<FollowedItem> get followedItems => Set.unmodifiable(_followedItems);
  Duration? get scheduledRefreshInterval => _scheduledRefreshInterval;
  bool get isRefreshScheduled => _refreshTimer?.isActive ?? false;
  bool get isChoosingCenterOnMap => _isChoosingCenterOnMap;
  String? get locationMessage => _locationMessage;

  AircraftFilter? _displayFilter;
  AircraftRoute? _mapRoute;
  AircraftRoute? get mapRoute => _mapRoute;

  void showRoute(AircraftRoute route, {required bool onMap}) {
    _displayFilter = AircraftFilter(
        label: 'Route: ${route.label}',
        routeOrigin: route.origin,
        routeDestination: route.destination);
    _mapRoute = onMap ? route : null;
    notifyListeners();
  }

  AircraftFilter? get displayFilter => _displayFilter;

  void setDisplayFilter(AircraftFilter? filter) {
    _displayFilter = filter;
    _mapRoute = null;
    notifyListeners();
  }

  List<TrackedAircraft> get visibleAircraft {
    final filter = _displayFilter;
    final queryMatches = filter?.query == null
        ? <String>{}
        : search(filter!.query!)
            .where((r) => r.type == SearchResultType.aircraft)
            .map((r) => r.identifier.toUpperCase())
            .toSet();
    return _aircraft.where((aircraft) {
      final altitude = aircraft.state.altitudeFeet;
      return altitude >= _settings.minimumAltitudeFeet &&
          altitude <= _settings.maximumAltitudeFeet &&
          (!_settings.savedOnly || _saved.contains(aircraft.state.icao24)) &&
          (filter == null ||
              filter.matches(aircraft,
                  matchesQuery: queryMatches
                      .contains(aircraft.state.icao24.toUpperCase())));
    }).toList(growable: false);
  }

  Future<void> initialize() async {
    try {
      await _airportSearchProvider?.initialize();
      await _airlineSearchProvider.initialize();
    } catch (_) {
      // Discovery catalog failure must not prevent the live app shell.
    }
    try {
      final persisted = await _preferencesStore.load();
      if (persisted != null) {
        _trackingCenter = persisted.trackingCenter;
        _settings = persisted.settings;
        _saved
          ..clear()
          ..addAll(persisted.savedAircraft);
        _followedItems
          ..clear()
          ..addAll(persisted.followedItems);
        for (final icao24 in _saved) {
          _followedItems.add(FollowedItem(
            type: FollowedItemType.aircraft,
            identifier: icao24,
            label: icao24.toUpperCase(),
          ));
        }
        notifyListeners();
      }
    } catch (_) {
      // Local persistence failure must not prevent the app shell or live feed.
    }
    await refresh();
    _scheduleRefresh();
  }

  Future<void> refresh() {
    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) return activeRefresh;
    final operation = _performRefresh();
    _activeRefresh = operation;
    return operation.whenComplete(() {
      if (identical(_activeRefresh, operation)) _activeRefresh = null;
    });
  }

  Future<void> _performRefresh() async {
    if (_aircraft.isEmpty) {
      _feedStatus = FeedStatus.connecting;
      notifyListeners();
    }
    try {
      final requestedCenter = _trackingCenter;
      final result = await _repository.loadNearby(
        centerLatitude: _trackingCenter.latitude,
        centerLongitude: _trackingCenter.longitude,
        radiusNauticalMiles: _settings.radarRangeNm.toDouble(),
      );
      if (!identical(requestedCenter, _trackingCenter)) return;
      _aircraft = _mergeObservedHistory(result);
      _feedStatus = FeedStatus.live;
    } on ProviderException catch (error) {
      _feedStatus = switch (error.type) {
        ProviderErrorType.networkUnavailable ||
        ProviderErrorType.timeout =>
          FeedStatus.offline,
        ProviderErrorType.rateLimited => FeedStatus.rateLimited,
        _ => _aircraft.isEmpty ? FeedStatus.error : FeedStatus.cached,
      };
    } catch (_) {
      _feedStatus = _aircraft.isEmpty ? FeedStatus.error : FeedStatus.cached;
    }
    notifyListeners();
  }

  List<TrackedAircraft> _mergeObservedHistory(List<TrackedAircraft> incoming) {
    final previousByIcao = {
      for (final item in _aircraft) item.state.icao24: item,
    };
    return incoming.map((item) {
      final previousTrail =
          previousByIcao[item.state.icao24]?.trail ?? const [];
      final currentPosition = AircraftPosition(
        latitude: item.state.latitude,
        longitude: item.state.longitude,
        observedAt: item.state.observedAt,
      );
      final alreadyObserved = previousTrail.isNotEmpty &&
          previousTrail.last.observedAt == currentPosition.observedAt;
      final trail = alreadyObserved
          ? previousTrail
          : <AircraftPosition>[...previousTrail, currentPosition];
      return TrackedAircraft(
        state: item.state,
        identity: item.identity,
        route: item.route,
        flight: item.flight,
        trail: trail.length <= 30 ? trail : trail.sublist(trail.length - 30),
      );
    }).toList(growable: false);
  }

  Duration get _effectiveRefreshInterval =>
      _settings.refreshInterval < minimumRefreshInterval
          ? minimumRefreshInterval
          : _settings.refreshInterval;

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _scheduledRefreshInterval = null;
    if (!_isActive) return;
    _scheduledRefreshInterval = _effectiveRefreshInterval;
    _refreshTimer = Timer.periodic(_effectiveRefreshInterval, (_) => refresh());
  }

  Future<void> setTrackingCenter(TrackingCenter center) async {
    _trackingCenter = center;
    _aircraft = const [];
    _isChoosingCenterOnMap = false;
    _locationMessage = null;
    notifyListeners();
    unawaited(_persist());
    await _refreshAfterCurrent();
  }

  Future<DeviceLocationStatus> useCurrentLocation() async {
    final provider = _deviceLocationProvider;
    if (provider == null) {
      _locationMessage = 'Current location is unavailable on this device.';
      notifyListeners();
      return DeviceLocationStatus.unavailable;
    }
    final result = await provider.getCurrentLocation();
    if (result.status == DeviceLocationStatus.available) {
      await setTrackingCenter(TrackingCenter(
        latitude: result.latitude!,
        longitude: result.longitude!,
        label: 'Current location',
        type: TrackingCenterType.device,
      ));
    } else {
      _locationMessage = switch (result.status) {
        DeviceLocationStatus.serviceDisabled =>
          'Location services are disabled.',
        DeviceLocationStatus.permissionDenied =>
          'Location permission was denied.',
        DeviceLocationStatus.permissionDeniedForever =>
          'Location permission is permanently denied. Enable it in system settings.',
        _ => 'Current location could not be determined.',
      };
      notifyListeners();
    }
    return result.status;
  }

  List<Airport> searchAirports(String query) =>
      _airportSearchProvider?.search(query) ?? const [];

  List<SearchResult> search(String query) => _searchService.search(
        query: query,
        aircraft: _aircraft,
        airlines: _airlineSearchProvider.airlines,
        airports: [
          ...searchAirports(query),
          if (UniversalSearchService.routeCodes(query) case final codes?) ...[
            ...searchAirports(codes.$1),
            ...searchAirports(codes.$2),
          ],
        ],
      );

  Future<void> chooseAirport(Airport airport) async {
    if (airport.latitude == null || airport.longitude == null) return;
    await setTrackingCenter(TrackingCenter(
      latitude: airport.latitude!,
      longitude: airport.longitude!,
      label: '${airport.displayCode} · ${airport.name}',
      type: TrackingCenterType.airport,
    ));
  }

  void beginMapCenterSelection() {
    _isChoosingCenterOnMap = true;
    notifyListeners();
  }

  void cancelMapCenterSelection() {
    _isChoosingCenterOnMap = false;
    notifyListeners();
  }

  void select(String? icao24) {
    _selectedIcao24 = icao24;
    notifyListeners();
  }

  Future<void> setRadarRange(int range) async {
    if (range == _settings.radarRangeNm) return;
    _settings = _settings.copyWith(radarRangeNm: range);
    notifyListeners();
    unawaited(_persist());
    await _refreshAfterCurrent();
  }

  void updateSettings(AppSettings settings) {
    final refreshIntervalChanged =
        settings.refreshInterval != _settings.refreshInterval;
    final radarRangeChanged = settings.radarRangeNm != _settings.radarRangeNm;
    _settings = settings;
    if (refreshIntervalChanged) _scheduleRefresh();
    notifyListeners();
    unawaited(_persist());
    if (radarRangeChanged) unawaited(_refreshAfterCurrent());
  }

  Future<void> _refreshAfterCurrent() async {
    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) await activeRefresh;
    await refresh();
  }

  Future<void> _persist() => _preferencesStore.save(PersistedAppState(
        trackingCenter: _trackingCenter,
        settings: _settings,
        savedAircraft: _saved,
        followedItems: _followedItems,
      ));

  void pause() {
    _isActive = false;
    _scheduleRefresh();
  }

  Future<void> resume() async {
    if (_isActive) return;
    _isActive = true;
    await refresh();
    _scheduleRefresh();
  }

  void toggleSaved(String icao24) {
    final aircraft =
        _aircraft.where((item) => item.state.icao24 == icao24).firstOrNull;
    final item = FollowedItem(
      type: FollowedItemType.aircraft,
      identifier: icao24,
      label: aircraft?.primaryIdentifier ?? icao24.toUpperCase(),
      subtitle: aircraft?.identity?.model,
    );
    if (!_saved.add(icao24)) {
      _saved.remove(icao24);
      _followedItems.remove(item);
    } else {
      _followedItems.add(item);
    }
    notifyListeners();
    unawaited(_persist());
  }

  bool isFollowing(FollowedItem item) => _followedItems.contains(item);

  void toggleFollowed(FollowedItem item) {
    if (!_followedItems.add(item)) _followedItems.remove(item);
    if (item.type == FollowedItemType.aircraft) {
      if (_followedItems.contains(item)) {
        _saved.add(item.identifier);
      } else {
        _saved.remove(item.identifier);
      }
    }
    notifyListeners();
    unawaited(_persist());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
