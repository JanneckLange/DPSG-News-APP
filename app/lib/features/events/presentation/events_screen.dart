import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/settings_repository.dart';
import '../../../core/services/hive_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(HiveService.getSettingsBox());
});

final eventsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final box = HiveService.getEventsBox();
  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

  void emitEvents() {
    final events = box.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    controller.add(events);
  }

  emitEvents();
  final subscription = box.watch().listen((_) => emitEvents());

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    final selectedDv = settingsRepo.getSelectedDv();

    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: eventsAsync.when(
        data: (events) {
          final filteredEvents = selectedDv == null
              ? events
              : events.where((event) => event['dv'] == selectedDv).toList();

          return filteredEvents.isEmpty
              ? const Center(child: Text('Keine Events verfügbar.'))
              : ListView.builder(
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return ListTile(
                      title: Text(event['title'] as String),
                      subtitle: Text(event['location'] as String),
                      trailing: Text(event['dv'] as String),
                    );
                  },
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Fehler beim Laden der Events: $error'),
        ),
      ),
    );
  }
}
