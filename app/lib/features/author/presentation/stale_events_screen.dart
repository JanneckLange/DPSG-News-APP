import 'package:flutter/material.dart';

import '../../events/presentation/event_detail_screen.dart';
import '../../events/presentation/event_list_tile.dart';

/// Zeigt die eigenen Events, die lange kein Update erhalten haben (siehe
/// [AuthorDashboardStats.staleEvents]) - geoeffnet ueber die entsprechende
/// Dashboard-Kachel im Autor-Bereich.
class StaleEventsScreen extends StatelessWidget {
  const StaleEventsScreen({super.key, required this.events});

  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lange kein Update')),
      body: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return EventListTile(
            title: event['title'] as String? ?? '',
            location: event['location'] as String? ?? '',
            dv: event['dv'] as String? ?? '',
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
