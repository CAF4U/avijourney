import 'dart:convert';
import '../../domain/models/aircraft_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/persistence/app_preferences_store.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/tracking_center.dart';
import '../../domain/models/followed_item.dart';

class SharedPreferencesAppStore implements AppPreferencesStore {
  const SharedPreferencesAppStore();

  static const _centerLatitude = 'tracking_center_latitude';
  static const _centerLongitude = 'tracking_center_longitude';
  static const _centerLabel = 'tracking_center_label';
  static const _centerType = 'tracking_center_type';
  static const _range = 'radar_range_nm';
  static const _refreshSeconds = 'refresh_seconds';
  static const _minimumAltitude = 'minimum_altitude_feet';
  static const _maximumAltitude = 'maximum_altitude_feet';
  static const _showTrails = 'show_trails';
  static const _showLabels = 'show_labels';
  static const _radarAppearance = 'radar_appearance';
  static const _mapAppearance = 'map_appearance';
  static const _appearance = 'appearance';
  static const _savedOnly = 'saved_only';
  static const _savedAircraft = 'saved_aircraft';
  static const _followedItems = 'followed_items_v1';

  @override
  Future<PersistedAppState?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final latitude = preferences.getDouble(_centerLatitude);
    final longitude = preferences.getDouble(_centerLongitude);
    final label = preferences.getString(_centerLabel);
    final typeName = preferences.getString(_centerType);
    final center = latitude == null || longitude == null || label == null
        ? TrackingCenter.heathrow
        : TrackingCenter(
            latitude: latitude,
            longitude: longitude,
            label: label,
            type: TrackingCenterType.values.firstWhere(
              (type) => type.name == typeName,
              orElse: () => TrackingCenterType.defaultLocation,
            ),
          );
    AppAppearance? screenAppearance(String key) =>
        switch (preferences.getString(key)) {
          'light' => AppAppearance.light,
          'dark' => AppAppearance.dark,
          _ => null,
        };
    return PersistedAppState(
      trackingCenter: center,
      settings: AppSettings(
        airportWeather: preferences.getBool('cap_airportWeather') ?? false,
        alertVibration: preferences.getBool('cap_alertVibration') ?? false,
        alertSound: preferences.getBool('cap_alertSound') ?? false,
        alertSquawkFollowedOnly:
            preferences.getBool('cap_alertSquawkFollowedOnly') ?? false,
        alertFollowedMovement:
            preferences.getBool('cap_alertFollowedMovement') ?? true,
        alertSquawk7700: preferences.getBool('cap_alertSquawk7700') ?? true,
        alertSquawk7600: preferences.getBool('cap_alertSquawk7600') ?? true,
        alertFollowedEntry:
            preferences.getBool('cap_alertFollowedEntry') ?? true,
        foregroundAlerts: preferences.getBool('cap_foregroundAlerts') ?? false,
        radarRangeNm: preferences.getInt(_range) ?? 20,
        refreshInterval:
            Duration(seconds: preferences.getInt(_refreshSeconds) ?? 60),
        minimumAltitudeFeet: preferences.getDouble(_minimumAltitude) ?? 0,
        maximumAltitudeFeet: preferences.getDouble(_maximumAltitude) ?? 50000,
        showTrails: preferences.getBool(_showTrails) ?? true,
        showLabels: preferences.getBool(_showLabels) ?? true,
        savedOnly: preferences.getBool(_savedOnly) ?? false,
        radarAppearance: screenAppearance(_radarAppearance),
        mapAppearance: screenAppearance(_mapAppearance),
        appearance: preferences.getString(_appearance) == 'light'
            ? AppAppearance.light
            : AppAppearance.dark,
      ),
      alerts:
          _readAlerts(preferences.getStringList('foreground_alerts_v1') ?? []),
      savedAircraft:
          (preferences.getStringList(_savedAircraft) ?? const []).toSet(),
      followedItems: (preferences.getStringList(_followedItems) ?? const [])
          .map(FollowedItem.fromStorageValue)
          .whereType<FollowedItem>()
          .toSet(),
    );
  }

  List<AircraftAlert> _readAlerts(List<String> values) {
    final result = <AircraftAlert>[];
    for (final raw in values.take(50)) {
      try {
        final a = jsonDecode(raw) as Map<String, dynamic>;
        result.add(AircraftAlert(
            id: a['id'] as String,
            icao24: a['icao24'] as String,
            identifier: a['identifier'] as String,
            kind: AircraftAlertKind.values.byName(a['kind'] as String),
            occurredAt: DateTime.parse(a['at'] as String).toUtc(),
            message: a['message'] as String,
            detail: a['detail'] as String));
      } catch (_) {/* Skip one corrupt record without dropping preferences. */}
    }
    return result;
  }

  @override
  Future<void> save(PersistedAppState state) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setStringList(
          'foreground_alerts_v1',
          state.alerts
              .take(50)
              .map((a) => jsonEncode({
                    'id': a.id,
                    'icao24': a.icao24,
                    'identifier': a.identifier,
                    'kind': a.kind.name,
                    'at': a.occurredAt.toIso8601String(),
                    'message': a.message,
                    'detail': a.detail
                  }))
              .toList()),
      preferences.setBool('cap_airportWeather', state.settings.airportWeather),
      preferences.setBool('cap_alertVibration', state.settings.alertVibration),
      preferences.setBool('cap_alertSound', state.settings.alertSound),
      preferences.setBool('cap_alertSquawkFollowedOnly',
          state.settings.alertSquawkFollowedOnly),
      preferences.setBool(
          'cap_alertFollowedMovement', state.settings.alertFollowedMovement),
      preferences.setBool(
          'cap_alertSquawk7700', state.settings.alertSquawk7700),
      preferences.setBool(
          'cap_alertSquawk7600', state.settings.alertSquawk7600),
      preferences.setBool(
          'cap_alertFollowedEntry', state.settings.alertFollowedEntry),
      preferences.setBool(
          'cap_foregroundAlerts', state.settings.foregroundAlerts),
      preferences.setDouble(_centerLatitude, state.trackingCenter.latitude),
      preferences.setDouble(_centerLongitude, state.trackingCenter.longitude),
      preferences.setString(_centerLabel, state.trackingCenter.label),
      preferences.setString(_centerType, state.trackingCenter.type.name),
      preferences.setInt(_range, state.settings.radarRangeNm),
      preferences.setInt(
          _refreshSeconds, state.settings.refreshInterval.inSeconds),
      preferences.setDouble(
          _minimumAltitude, state.settings.minimumAltitudeFeet),
      preferences.setDouble(
          _maximumAltitude, state.settings.maximumAltitudeFeet),
      preferences.setBool(_showTrails, state.settings.showTrails),
      preferences.setBool(_showLabels, state.settings.showLabels),
      preferences.setBool(_savedOnly, state.settings.savedOnly),
      preferences.setString(_appearance, state.settings.appearance.name),
      state.settings.radarAppearance == null
          ? preferences.remove(_radarAppearance)
          : preferences.setString(
              _radarAppearance, state.settings.radarAppearance!.name),
      state.settings.mapAppearance == null
          ? preferences.remove(_mapAppearance)
          : preferences.setString(
              _mapAppearance, state.settings.mapAppearance!.name),
      preferences.setStringList(
          _savedAircraft, state.savedAircraft.toList(growable: false)),
      preferences.setStringList(_followedItems,
          state.followedItems.map((item) => item.storageValue).toList()),
    ]);
  }
}
