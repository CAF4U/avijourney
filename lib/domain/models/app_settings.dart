enum AppAppearance { dark, light }

class AppSettings {
  const AppSettings({
    this.radarRangeNm = 20,
    this.refreshInterval = const Duration(seconds: 60),
    this.minimumAltitudeFeet = 0,
    this.maximumAltitudeFeet = 50000,
    this.showTrails = true,
    this.showLabels = true,
    this.savedOnly = false,
    this.appearance = AppAppearance.dark,
    this.radarAppearance,
    this.foregroundAlerts = false,
    this.alertFollowedEntry = true,
    this.alertSquawk7600 = true,
    this.alertSquawk7700 = true,
    this.alertFollowedMovement = true,
    this.alertSquawkFollowedOnly = false,
    this.alertSound = false,
    this.alertVibration = false,
    this.airportWeather = false,
    this.mapAppearance,
  });

  final bool foregroundAlerts;
  final bool alertFollowedEntry;
  final bool alertSquawk7600;
  final bool alertSquawk7700;
  final bool alertFollowedMovement;
  final bool alertSquawkFollowedOnly;
  final bool alertSound;
  final bool alertVibration;
  final bool airportWeather;
  final int radarRangeNm;
  final Duration refreshInterval;
  final double minimumAltitudeFeet;
  final double maximumAltitudeFeet;
  final bool showTrails;
  final bool showLabels;
  final bool savedOnly;
  final AppAppearance appearance;
  final AppAppearance? radarAppearance;
  final AppAppearance? mapAppearance;
  AppAppearance get effectiveRadarAppearance => radarAppearance ?? appearance;
  AppAppearance get effectiveMapAppearance => mapAppearance ?? appearance;

  AppSettings copyWith({
    bool? foregroundAlerts,
    bool? alertFollowedEntry,
    bool? alertSquawk7600,
    bool? alertSquawk7700,
    bool? alertFollowedMovement,
    bool? alertSquawkFollowedOnly,
    bool? alertSound,
    bool? alertVibration,
    bool? airportWeather,
    int? radarRangeNm,
    Duration? refreshInterval,
    double? minimumAltitudeFeet,
    double? maximumAltitudeFeet,
    bool? showTrails,
    bool? showLabels,
    bool? savedOnly,
    AppAppearance? appearance,
    AppAppearance? radarAppearance,
    AppAppearance? mapAppearance,
  }) =>
      AppSettings(
        foregroundAlerts: foregroundAlerts ?? this.foregroundAlerts,
        alertFollowedEntry: alertFollowedEntry ?? this.alertFollowedEntry,
        alertSquawk7600: alertSquawk7600 ?? this.alertSquawk7600,
        alertSquawk7700: alertSquawk7700 ?? this.alertSquawk7700,
        alertFollowedMovement:
            alertFollowedMovement ?? this.alertFollowedMovement,
        alertSquawkFollowedOnly:
            alertSquawkFollowedOnly ?? this.alertSquawkFollowedOnly,
        alertSound: alertSound ?? this.alertSound,
        alertVibration: alertVibration ?? this.alertVibration,
        airportWeather: airportWeather ?? this.airportWeather,
        radarRangeNm: radarRangeNm ?? this.radarRangeNm,
        refreshInterval: refreshInterval ?? this.refreshInterval,
        minimumAltitudeFeet: minimumAltitudeFeet ?? this.minimumAltitudeFeet,
        maximumAltitudeFeet: maximumAltitudeFeet ?? this.maximumAltitudeFeet,
        showTrails: showTrails ?? this.showTrails,
        showLabels: showLabels ?? this.showLabels,
        savedOnly: savedOnly ?? this.savedOnly,
        appearance: appearance ?? this.appearance,
        radarAppearance: radarAppearance ?? this.radarAppearance,
        mapAppearance: mapAppearance ?? this.mapAppearance,
      );
}
