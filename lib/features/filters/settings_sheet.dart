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
            const Text('Appearance'),
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
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Tracking location'),
                subtit…3394 tokens truncated…  fontSize: 10, fontWeight: FontWeight.bold))));
  }
}
