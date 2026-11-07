import '../../domain/models/app_settings.dart';
import '../../domain/models/aircraft_alert.dart';
import '../../domain/models/tracking_center.dart';
import '../../domain/models/followed_item.dart';

class PersistedAppState {
  const PersistedAppState({
    required this.trackingCenter,
    required this.settings,
    required this.savedAircraft,
    this.followedItems = const {},
    this.alerts = const [],
  });

  final TrackingCenter trackingCenter;
  final AppSettings settings;
  final Set<String> savedAircraft;
  final Set<FollowedItem> followedItems;
  final List<AircraftAlert> alerts;
}

abstract interface class AppPreferencesStore {
  Future<PersistedAppState?> load();
  Future<void> save(PersistedAppState state);
}

class NoOpAppPreferencesStore implements AppPreferencesStore {
  const NoOpAppPreferencesStore();

  @override
  Future<PersistedAppState?> load() async => null;

  @override
  Future<void> save(PersistedAppState state) async {}
}
