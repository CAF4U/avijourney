import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/app_controller.dart';

class ManualRefreshButton extends StatelessWidget {
  const ManualRefreshButton(
      {required this.controller, required this.surface, super.key});
  final AppController controller;
  final String surface;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final remaining = controller.manualRefreshSecondsRemaining;
        return IconButton(
          key: Key('manualRefresh-$surface'),
          tooltip: controller.isRefreshing
              ? 'Refreshing aircraft'
              : remaining > 0
                  ? 'Refresh available in ${remaining}s'
                  : 'Refresh aircraft',
          onPressed: controller.canManuallyRefresh
              ? () => unawaited(controller.manualRefresh())
              : null,
          icon: controller.isRefreshing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : remaining > 0
                  ? Text('${remaining}s', style: const TextStyle(fontSize: 11))
                  : const Icon(Icons.refresh),
        );
      });
}
