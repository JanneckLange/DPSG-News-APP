import 'package:flutter/material.dart';

import '../utils/date_format_utils.dart';

/// Kompaktes "Kalenderblatt" mit grosser Tageszahl und Monats-Kuerzel
/// darunter, z.B. fuer den linken Rand eines Event-Listeneintrags. Reine
/// Darstellungskomponente ohne eigene Datenlogik.
class CalendarLeaf extends StatelessWidget {
  const CalendarLeaf({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${date.day}',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, height: 1.0),
          ),
          const SizedBox(height: 2),
          Text(
            formatMonthAbbreviation(date),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
