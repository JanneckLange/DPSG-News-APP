import 'package:flutter/material.dart';

/// Chip mit Icon + Label + Wert, z.B. "DV: Köln" statt eines undifferenzierten
/// Chips. Optional mit Akzentfarbe (z.B. Stufenfarbe fuer Topic-Chips).
class LabeledChip extends StatelessWidget {
  const LabeledChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.onSurfaceVariant;

    return Chip(
      avatar: Icon(icon, size: 18, color: accent),
      label: Text('$label: $value'),
      side: color != null ? BorderSide(color: color!) : null,
    );
  }
}
