import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/presentation/event_detail_screen.dart';
import '../../events/presentation/event_list_tile.dart';
import '../../settings/data/dv_tree_provider.dart';

/// Zeigt die eigenen Events, die lange kein Update erhalten haben (siehe
/// [AuthorDashboardStats.staleEvents]) - geoeffnet ueber die entsprechende
/// Dashboard-Kachel im Autor-Bereich.
class StaleEventsScreen extends ConsumerWidget {
  const StaleEventsScreen({super.key, required this.events});

  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layerNamesById = ref.watch(layerNamesByIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lange kein Update')),
      body: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return EventListTile(
            title: event['title'] as String? ?? '',
            location: event['location'] as String? ?? '',
            layerName: layerNamesById[(event['layerId'] as num?)?.toInt()] ??
                'Kein DV',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(event: event),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
