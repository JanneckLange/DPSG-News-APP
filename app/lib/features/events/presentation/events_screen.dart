import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../author/data/author_auth_provider.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../../settings/data/settings_repository.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import 'event_detail_screen.dart';
import 'event_editor_sheet.dart';
import 'event_list_tile.dart';

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
    final selectedLayerIds = settingsRepo.getSelectedLayerIds();
    final layerNamesById = ref.watch(layerNamesByIdProvider);
    final authorAuth = ref.watch(authorAuthProvider);

    final syncError = ref.watch(sync_service.eventSyncStatusProvider);
    final analytics = ref.read(analyticsServiceProvider);

    Widget buildContent(List<Map<String, dynamic>> events) {
      final filteredEvents = selectedLayerIds.isEmpty
          ? events
          : events
              .where((event) => selectedLayerIds
                  .contains((event['layerId'] as num?)?.toInt()))
              .toList();

      final listView = filteredEvents.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Keine Events verfügbar.')))
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) {
                final event = filteredEvents[index];
                final eventAuthorId = event['authorId'] is num
                    ? (event['authorId'] as num).toInt()
                    : null;
                final canManageEvent = authorAuth.isLoggedIn &&
                    !authorAuth.isLocked &&
                    !authorAuth.requiresPasswordChange &&
                    (authorAuth.isAdmin ||
                        eventAuthorId == authorAuth.authorId);
                final canEdit = canManageEvent;
                final canDelete = canManageEvent;
                final createdBy = event['createdBy'] as String?;
                final eventLayerId = (event['layerId'] as num?)?.toInt();
                return EventListTile(
                  title: event['title'] as String? ?? '',
                  location: event['location'] as String? ?? '',
                  layerName: layerNamesById[eventLayerId] ?? 'Unbekannt',
                  createdBy: authorAuth.isAdmin ? createdBy : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EventDetailScreen(event: event),
                      ),
                    );
                  },
                  onEdit: canEdit
                      ? () async {
                          unawaited(
                            analytics.trackFeatureEvent(
                              'event_edit_started',
                              screen: 'events',
                              action: 'edit',
                              target: event['title']?.toString() ?? 'unknown',
                            ),
                          );
                          final changed =
                              await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (context) =>
                                  EventEditorPage(existingEvent: event),
                            ),
                          );
                          if (changed == true) {
                            await ref
                                .read(sync_service.syncServiceProvider)
                                .syncEvents();
                          }
                        }
                      : null,
                  onDelete: canDelete
                      ? () async {
                          unawaited(
                            analytics.trackFeatureEvent(
                              'event_delete_started',
                              screen: 'events',
                              action: 'delete',
                              target: event['title']?.toString() ?? 'unknown',
                            ),
                          );
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Event löschen'),
                              content: const Text(
                                  'Möchtest du dieses Event löschen?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Abbrechen'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Löschen'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final token = authorAuth.token;
                            if (token == null) {
                              return;
                            }
                            await ref
                                .read(sync_service.remoteEventSourceProvider)
                                .deleteEvent(
                                  token: token,
                                  eventId: (event['id'] as num).toInt(),
                                );
                            await ref
                                .read(sync_service.syncServiceProvider)
                                .syncEvents();
                          }
                        }
                      : null,
                );
              },
            );

      unawaited(
        analytics.trackFeatureEvent(
          'event_list_viewed',
          screen: 'events',
          source: 'events_screen',
          additionalProperties: {
            'selected_dv_count': selectedLayerIds.length,
            'total_event_count': events.length,
          },
        ),
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
                unawaited(
                  analytics.trackFeatureEvent(
                    'event_list_refreshed',
                    screen: 'events',
                    action: 'refresh',
                  ),
                );
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
