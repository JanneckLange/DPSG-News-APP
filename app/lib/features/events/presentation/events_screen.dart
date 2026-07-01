import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/settings_repository.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;

final eventsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final box = HiveService.getEventsBox();
  return Stream<List<Map<String, dynamic>>>.multi((streamController) {
    void emitEvents() {
      final events = box.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      streamController.add(events);
    }

    emitEvents();
    final subscription = box.watch().listen((_) => emitEvents());
    streamController.onCancel = () => subscription.cancel();
  });
});

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    final selectedDvs = settingsRepo.getSelectedDvs();

    final syncError = ref.watch(sync_service.eventSyncStatusProvider);

    Widget buildContent(List<Map<String, dynamic>> events) {
      final filteredEvents = selectedDvs.isEmpty
          ? events
          : events.where((event) => selectedDvs.contains(event['dv'] as String)).toList();

      final listView = filteredEvents.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Keine Events verfügbar.')))],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
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

      return Column(
        children: [
          if (syncError != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(12),
              child: Text(
                syncError,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(sync_service.syncServiceProvider).syncEvents();
              },
              child: listView,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: eventsAsync.when(
        data: buildContent,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => RefreshIndicator(
          onRefresh: () async {
            await ref.read(sync_service.syncServiceProvider).syncEvents();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Fehler beim Laden der Events: $error'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
