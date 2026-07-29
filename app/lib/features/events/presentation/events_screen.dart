import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/notification_service.dart';
import '../../author/data/author_auth_provider.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/dv_selection_screen.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../../shared/utils/date_format_utils.dart';
import '../../../shared/widgets/dashboard_stat_row.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_card_list.dart';
import '../../../shared/widgets/stat_tile.dart';
import 'event_detail_screen.dart';
import 'event_list_tile.dart';
import 'events_dashboard_stats.dart';

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

/// Ein Eintrag der gemischten Event-Liste: entweder ein Monats-Trenner (nur
/// im nicht gemerkten Teil) oder ein Event selbst.
sealed class _ListEntry {}

class _MonthHeaderEntry extends _ListEntry {
  _MonthHeaderEntry(this.label);
  final String label;
}

class _EventEntry extends _ListEntry {
  _EventEntry(this.event);
  final Map<String, dynamic> event;
}

/// Gemerkte Events zuerst (sortiert nach Startdatum, ohne Trenner), danach
/// alle uebrigen Events gruppiert nach Monat (mit Monats-Trenner), ebenfalls
/// nach Startdatum sortiert. Events ohne parsbares Startdatum landen ans
/// Ende ihrer jeweiligen Gruppe.
List<_ListEntry> _buildListEntries(
  List<Map<String, dynamic>> events,
  Set<String> savedEventIds,
) {
  DateTime? startOf(Map<String, dynamic> e) =>
      DateTime.tryParse(e['startDate']?.toString() ?? '')?.toLocal();

  final saved = <Map<String, dynamic>>[];
  final rest = <Map<String, dynamic>>[];
  for (final event in events) {
    final id = event['id']?.toString() ?? '';
    (savedEventIds.contains(id) ? saved : rest).add(event);
  }

  int compareByStart(Map<String, dynamic> a, Map<String, dynamic> b) {
    final startA = startOf(a);
    final startB = startOf(b);
    if (startA == null && startB == null) return 0;
    if (startA == null) return 1;
    if (startB == null) return -1;
    return startA.compareTo(startB);
  }

  saved.sort(compareByStart);
  rest.sort(compareByStart);

  final entries = <_ListEntry>[for (final event in saved) _EventEntry(event)];

  String? currentMonthKey;
  for (final event in rest) {
    final start = startOf(event);
    final key = start == null ? 'unbekannt' : '${start.year}-${start.month}';
    if (key != currentMonthKey) {
      currentMonthKey = key;
      entries.add(_MonthHeaderEntry(
        start == null ? 'Ohne Datum' : formatMonthYearHeader(start),
      ));
    }
    entries.add(_EventEntry(event));
  }

  return entries;
}

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  @override
  void initState() {
    super.initState();
    // Ungedrosselt aufgerufen, die Drossel-Logik (max. alle 120s) sitzt
    // zentral in SyncService.syncEvents.
    Future.microtask(
        () => ref.read(sync_service.syncServiceProvider).syncEvents());
  }

  Future<void> _toggleSaved(String eventId, bool isSaved) async {
    final notifier = ref.read(savedEventIdsProvider.notifier);
    if (isSaved) {
      await notifier.removeEvent(eventId);
    } else {
      await notifier.addEvent(eventId);
    }
    await ref.read(notificationServiceProvider).refreshTopicSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    final selectedLayerIds = settingsRepo.getSelectedLayerIds();
    final layerNamesById = ref.watch(layerNamesByIdProvider);
    final savedEventIds = ref.watch(savedEventIdsProvider);
    final viewedAt = ref.watch(eventViewedAtProvider);
    final authorAuth = ref.watch(authorAuthProvider);
    final showDv = selectedLayerIds.length > 1;

    final syncError = ref.watch(sync_service.eventSyncStatusProvider);
    final analytics = ref.read(analyticsServiceProvider);

    Widget buildContent(List<Map<String, dynamic>> events) {
      final filteredEvents = selectedLayerIds.isEmpty
          ? events
          : events
              .where((event) => selectedLayerIds
                  .contains((event['layerId'] as num?)?.toInt()))
              .toList();

      final stats = EventsDashboardStats.fromEvents(
          filteredEvents, savedEventIds, viewedAt);
      final entries = _buildListEntries(filteredEvents, savedEventIds);

      final listView = filteredEvents.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 48),
                EmptyState(
                  icon: Icons.event_busy,
                  message: 'Keine Events verfügbar.',
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                if (entry is _MonthHeaderEntry) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      entry.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  );
                }

                final event = (entry as _EventEntry).event;
                final id = event['id']?.toString() ?? '';
                final startDate =
                    DateTime.tryParse(event['startDate']?.toString() ?? '');
                final lastUpdateAt =
                    DateTime.tryParse(event['lastUpdateAt']?.toString() ?? '');
                final createdAt =
                    DateTime.tryParse(event['createdAt']?.toString() ?? '');
                final viewed = viewedAt[id];
                final isSaved = savedEventIds.contains(id);
                final createdBy = event['createdBy'] as String?;
                final eventLayerId = (event['layerId'] as num?)?.toInt();

                final showNewUpdateBadge = isSaved &&
                    lastUpdateAt != null &&
                    (viewed == null || lastUpdateAt.isAfter(viewed));
                final showNewBadge = createdAt != null &&
                    DateTime.now().difference(createdAt) <
                        const Duration(days: 30) &&
                    !viewedAt.containsKey(id);

                return Dismissible(
                  key: ValueKey('event-$id'),
                  background: Container(
                    color: Colors.green,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.bookmark, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.blueGrey,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.done_all, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      await _toggleSaved(id, isSaved);
                    } else {
                      await ref
                          .read(eventViewedAtProvider.notifier)
                          .markViewed(id);
                    }
                    return false;
                  },
                  child: EventListTile(
                    title: event['title'] as String? ?? '',
                    location: event['locationAddress'] as String?,
                    layerName: layerNamesById[eventLayerId] ?? 'Unbekannt',
                    topic: event['topic'] as String?,
                    startDate: startDate,
                    createdBy: authorAuth.isAdmin ? createdBy : null,
                    showDv: showDv,
                    isSaved: isSaved,
                    showNewUpdateBadge: showNewUpdateBadge,
                    showNewBadge: showNewBadge,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings:
                              const RouteSettings(name: 'EventDetailScreen'),
                          builder: (context) => EventDetailScreen(event: event),
                        ),
                      );
                    },
                  ),
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
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                syncError,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          DashboardStatRow(
            tiles: [
              StatTile(
                icon: Icons.calendar_month,
                value: '${stats.nextMonthCount}',
                label: 'Innerhalb des nächsten Monats',
              ),
              StatTile(
                icon: Icons.update,
                value: '${stats.newUpdatesCount}',
                label: 'Neue Updates',
              ),
              StatTile(
                icon: Icons.fiber_new,
                value: '${stats.newEventsCount}',
                label: 'Neue Events',
              ),
            ],
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
                await ref
                    .read(sync_service.syncServiceProvider)
                    .syncEvents(force: true);
              },
              child: listView,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            tooltip: 'DV-Auswahl',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'DvSelectionScreen'),
                  builder: (context) => const DvSelectionScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: eventsAsync.when(
        data: buildContent,
        loading: () => const SkeletonCardList(),
        error: (error, stackTrace) => RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(sync_service.syncServiceProvider)
                .syncEvents(force: true);
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
