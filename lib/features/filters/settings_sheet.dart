import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/models/app_settings.dart';
import 'tracking_location_sheet.dart';

Future<void> showSettingsSheet(BuildContext context, AppController controller,
        {required VoidCallback onChooseOnMap}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _SettingsSheet(
            controller: controller, onChooseOnMap: onChooseOnMap));

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.controller, required this.onChooseOnMap});
  final AppController controller;
  final VoidCallback onChooseOnMap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final settings = controller.settings;
          return ListView(padding: const EdgeInsets.all(24), children: [
            Row(children: [
              Expanded(
                  child: Text('Filters & settings',
                      style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ]),
            const SizedBox(height: 16),
            const Text('App appearance'),
            SegmentedButton<AppAppearance>(
              key: const Key('appearanceSetting'),
              segments: const [
                ButtonSegment(
                    value: AppAppearance.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode)),
                ButtonSegment(
                    value: AppAppearance.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode)),
              ],
              selected: {settings.appearance},
              onSelectionChanged: (value) => controller.updateSettings(
                  controller.settings.copyWith(appearance: value.first)),
            ),
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Radar and Map have their own Dark / Light controls on each screen. Reset settings restores their app-appearance defaults.')),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Tracking location'),
                subtitle: Text(controller.trackingCenter.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showTrackingLocationSheet(context, controller,
                    onChooseOnMap: onChooseOnMap)),
            const Divider(),
            Text('Radar range · ${controller.settings.radarRangeNm} NM'),
            SegmentedButton<int>(
                segments: const [20, 80, 140, 200]
                    .map((value) =>
                        ButtonSegment(value: value, label: Text('$value')))
                    .toList(),
                selected: {controller.settings.radarRangeNm},
                onSelectionChanged: (value) =>
                    controller.setRadarRange(value.first)),
            const SizedBox(height: 20),
            const Text('Refresh interval'),
            DropdownButton<Duration>(
                isExpanded: true,
                value: controller.settings.refreshInterval,
                items: const [
                  Duration(seconds: 30),
                  Duration(seconds: 60),
                  Duration(minutes: 2),
                  Duration(minutes: 5)
                ]
                    .map((duration) => DropdownMenuItem(
                        value: duration,
                        child: Text(duration.inSeconds <= 60
                            ? '${duration.inSeconds} seconds${duration.inSeconds == 60 ? ' (recommended)' : ''}'
                            : '${duration.inMinutes} minutes')))
                    .toList(),
                onChanged: (value) {
                  if (value != null)
                    controller.updateSettings(
                        controller.settings.copyWith(refreshInterval: value));
                }),
            const Text('Faster refresh uses more free-provider quota.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show trails'),
                value: controller.settings.showTrails,
                onChanged: (value) => controller.updateSettings(
                    controller.settings.copyWith(showTrails: value))),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show labels'),
                value: controller.settings.showLabels,
                onChanged: (value) => controller.updateSettings(
                    controller.settings.copyWith(showLabels: value))),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Saved aircraft only'),
                value: controller.settings.savedOnly,
                onChanged: (value) => controller.updateSettings(
                    controller.settings.copyWith(savedOnly: value))),
            Text(
                'Altitude · ${settings.minimumAltitudeFeet.round()}–${settings.maximumAltitudeFeet.round()} ft'),
            RangeSlider(
                values: RangeValues(
                    settings.minimumAltitudeFeet, settings.maximumAltitudeFeet),
                min: 0,
                max: 50000,
                divisions: 50,
                onChanged: (value) => controller.updateSettings(
                    controller.settings.copyWith(
                        minimumAltitudeFeet: value.start,
                        maximumAltitudeFeet: value.end))),
            const Divider(),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sensors),
                title: const Text('Provider / feed'),
                subtitle: Text(
                    '${controller.feedName} · ${_statusLabel(controller.feedStatus)}')),
            OutlinedButton(
                onPressed: () => controller.updateSettings(const AppSettings()),
                child: const Text('Reset settings')),
          ]);
        });
  }

  String _statusLabel(FeedStatus status) => switch (status) {
        FeedStatus.connecting => 'connecting',
        FeedStatus.live => 'live',
        FeedStatus.cached => 'cached / stale',
        FeedStatus.offline => 'offline',
        FeedStatus.rateLimited => 'rate limited',
        FeedStatus.error => 'feed error',
      };
}
