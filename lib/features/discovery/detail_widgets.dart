import 'package:flutter/material.dart';

class DetailSection extends StatelessWidget {
  const DetailSection(
      {required this.title,
      required this.rows,
      this.actions = const {},
      this.onTitleTap,
      this.trailing,
      super.key});
  final String title;
  final Widget? trailing;
  final Map<String, String> rows;
  final Map<String, VoidCallback> actions;
  final VoidCallback? onTitleTap;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (onTitleTap == null)
              Row(children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                if (trailing != null) trailing!,
              ])
            else
              InkWell(
                  key: Key('detailTitle-$title'),
                  onTap: onTitleTap,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Expanded(
                            child: Text(title,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary))),
                        const Icon(Icons.chevron_right, size: 20),
                      ]))),
            const Divider(),
            for (final row in rows.entries)
              if (actions[row.key] case final action?)
                InkWell(
                    key: Key('detail-$title-${row.key}'),
                    onTap: action,
                    child: _row(context, row, linked: true))
              else
                _row(context, row),
          ])));

  Widget _row(BuildContext context, MapEntry<String, String> row,
          {bool linked = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                flex: 2,
                child: Text(row.key,
                    style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(width: 12),
            Expanded(
                flex: 3,
                child: Text(row.value,
                    style: linked
                        ? TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline)
                        : null)),
            if (linked) const Icon(Icons.chevron_right, size: 18),
          ]));
}
