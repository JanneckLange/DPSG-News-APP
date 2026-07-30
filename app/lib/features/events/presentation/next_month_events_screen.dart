import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/dv_tree_provider.dart';
import 'event_detail_screen.dart';
import 'event_list_tile.dart';

/// Zeigt die Events, die in den naechsten 30 Tagen starten (siehe
/// [EventsDashboardStats.nextMonthEvents]) - geoeffnet ueber die
/// entsprechende Dashboard-Kachel in der Events-Uebersicht.
class NextMonthEventsScreen extends ConsumerWidget {
  const NextMonthEventsScreen({super.key, required this.events});

  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layerNamesById = ref.watch(layerNamesByIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nächste 30 Tage')),
      body: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return EventListTile(
            title: event['title'] as String? ?? '',
            location: event['locationAddress'] as String?,
            layerName: layerNamesById[(event['layerId'] as num?)?.toInt()] ??
                'Kein DV',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'EventDetailScreen'),
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
