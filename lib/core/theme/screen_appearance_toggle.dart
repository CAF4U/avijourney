import 'package:flutter/material.dart';
import '../../domain/models/app_settings.dart';

class ScreenAppearanceToggle extends StatelessWidget {
  const ScreenAppearanceToggle(
      {required this.screen,
      required this.value,
      required this.onChanged,
      super.key});
  final String screen;
  final AppAppearance value;
  final ValueChanged<AppAppearance> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$screen appearance',
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: SegmentedButton<AppAppearance>(
            key: Key('${screen.toLowerCase()}AppearanceToggle'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: AppAppearance.dark,
                  label: Text('Dark'),
                  tooltip: 'Dark appearance for this screen'),
              ButtonSegment(
                  value: AppAppearance.light,
                  label: Text('Light'),
                  tooltip: 'Light appearance for this screen'),
            ],
            selected: {value},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
      );
}
