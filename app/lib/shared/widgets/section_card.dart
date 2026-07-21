import 'package:flutter/material.dart';

/// Visuell abgesetzter Abschnitt (z.B. Updates-Bereich auf der Event-Detailseite)
/// mit optionalem Titel und Hintergrundfarbe, statt eines reinen Divider-Trenners.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.background,
  });

  final String? title;
  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
