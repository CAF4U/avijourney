import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../aircraft_detail/aircraft_detail_sheet.dart';

void openForegroundAlerts(BuildContext context, AppController controller) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ForegroundAlertsPage(controller: controller)));

class ForegroundAlertsPage extends StatelessWidget {
  const ForegroundAlertsPage({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
          key: const Key('foregroundAlertsPage'),
          appBar: AppBar(title: const Text('Foreground alerts'), actions: [
            IconButton(
                tooltip: 'Clear alert history',
                onPressed: controller.alerts.isEmpty
                    ? null
                    : () async {
                        final clear = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                                    title: const Text('Clear alert history?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('Cancel')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text('Clear'))
                                    ]));
                        if (clear == true) controller.clearAlerts();
                      },
                icon: const Icon(Icons.delete_outline)),
          ]),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            SwitchListTile(
                key: const Key('alertsCapabilitySwitch'),
                title: const Text('Foreground alerts'),
                subtitle: const Text(
                    'Only while this app is active. No background or global monitoring.'),
                value: controller.settings.foregroundAlerts,
                onChanged: (v) => controller.updateSettings(
                    controller.settings.copyWith(foregroundAlerts: v))),
            const Text(
                'Latest 50 alerts are stored on this device. Takeoff/landing estimates require two fresh ground-state transitions; timestamps are detection times, not confirmed ACARS OOOI events.'),
            if (controller.alerts.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'No alerts recorded yet. Follow aircraft and enable alert rules in settings.')),
            for (final alert in controller.alerts)
              Card(
                  child: ListTile(
                title: Text('${alert.identifier} · ${alert.message}'),
                subtitle:
                    Text('${alert.occurredAt.toLocal()}\n${alert.detail}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final aircraft = controller.aircraft
                      .where((a) =>
                          a.state.icao24.toUpperCase() ==
                          alert.icao24.toUpperCase())
                      .firstOrNull;
                  if (aircraft != null) {
                    showAircraftDetail(context, aircraft, controller);
                  } else {
                    showDialog<void>(
                        context: context,
                        builder: (c) => AlertDialog(
                                title: Text(alert.identifier),
                                content: Text(
                                    '${alert.message}\n${alert.detail}\nAircraft is no longer in the acquired snapshot.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('Close'))
                                ]));
                  }
                },
              )),
          ])));
}

class ForegroundAlertBanner extends StatelessWidget {
  const ForegroundAlertBanner({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final notice = controller.foregroundNotice;
    if (notice == null || !controller.settings.foregroundAlerts)
      return const SizedBox.shrink();
    return Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: ListTile(
          key: const Key('foregroundAlertBanner'),
          dense: true,
          leading: const Icon(Icons.notifications_active),
          title: Text('${notice.identifier} · ${notice.message}',
              maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => openForegroundAlerts(context, controller),
          trailing: IconButton(
              tooltip: 'Dismiss alert banner',
              onPressed: controller.dismissForegroundNotice,
              icon: const Icon(Icons.close)),
        ));
  }
}
