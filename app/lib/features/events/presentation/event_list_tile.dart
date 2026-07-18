import 'package:flutter/material.dart';

import '../../../shared/widgets/calendar_leaf.dart';

/// Karten-basierter Listeneintrag fuer Events und Entwuerfe. Wird sowohl in
/// der oeffentlichen Events-Liste als auch im Autor-Bereich verwendet.
///
/// Fuer veroeffentlichte Events werden [onEdit]/[onDelete] bewusst nicht
/// gesetzt (Bearbeiten/Loeschen sitzt auf der Event-Detailseite) - nur bei
/// Entwuerfen (kein Detailscreen vorhanden) bleiben sie aktiv.
class EventListTile extends StatelessWidget {
  const EventListTile({
    super.key,
    required this.title,
    required this.location,
    required this.dv,
    this.topic,
    this.startDate,
    this.createdBy,
    this.showDv = true,
    this.isSaved = false,
    this.showNewUpdateBadge = false,
    this.showNewBadge = false,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  final String title;
  final String location;
  final String dv;
  final String? topic;
  final DateTime? startDate;
  final String? createdBy;
  final bool showDv;
  final bool isSaved;
  final bool showNewUpdateBadge;
  final bool showNewBadge;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasActions = onEdit != null || onDelete != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (startDate != null) ...[
                CalendarLeaf(date: startDate!),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isSaved) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.bookmark, size: 18, color: scheme.primary),
                        ],
                        if (showNewBadge) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'NEU',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(location, style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                    ),
                    if (createdBy != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Erstellt von: $createdBy',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (showDv || (topic != null && topic!.isNotEmpty)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (showDv)
                            Chip(
                              label: Text(dv),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          if (topic != null && topic!.isNotEmpty)
                            Chip(
                              label: Text(topic!),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: scheme.secondaryContainer,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (showNewUpdateBadge)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Badge(backgroundColor: scheme.error, smallSize: 8),
                ),
              if (onEdit != null)
                IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
              if (onDelete != null)
                IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
              if (!hasActions)
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
