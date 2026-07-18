import 'package:flutter/material.dart';

/// Platzhalter fuer eine kuenftige Kartenansicht des Event-Orts, sobald
/// Adressen als echte Geo-Location vorliegen. Ersetzt den bisherigen reinen
/// Text-/Chip-Ort auf der Event-Detailseite durch eine volle Breite
/// einnehmende Flaeche, die bereits wie ein Karten-Slot aussieht.
class LocationPlaceholder extends StatelessWidget {
  const LocationPlaceholder({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: 96,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
