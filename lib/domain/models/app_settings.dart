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
  });

  final int radarRangeNm;
  final Duration refreshInterval;
  final double minimumAltitudeFeet;
  final double maximumAltitudeFeet;
  final bool showTrails;
  final bool showLabels;
  final bool savedOnly;
  final AppAppearance appearance;

  AppSettings copyWith({
    int? radarRangeNm,
    Duration? refreshInterval,
    double? minimumAltitudeFeet,
    double? maximumAltitudeFeet,
    bool? showTrails,
    bool? showLabels,
    bool? savedOnly,
    AppAppearance? appearance,
  }) =>
      AppSettings(
        radarRangeNm: radarRangeNm ?? this.radarRangeNm,
        refreshInterval: refreshInterval ?? this.refreshInterval,
        minimumAltitudeFeet: minimumAltitudeFeet ?? this.minimumAltitudeFeet,
        maximumAltitudeFeet: maximumAltitudeFeet ?? this.maximumAltitudeFeet,
        showTrails: showTrails ?? this.showTrails,
        showLabels: showLabels ?? this.showLabels,
        savedOnly: savedOnly ?? this.savedOnly,
        appearance: appearance ?? this.appearance,
      );
}
