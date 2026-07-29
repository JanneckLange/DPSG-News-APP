import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/error_toast_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../../shared/widgets/dashboard_stat_row.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_card_list.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../events/presentation/event_detail_screen.dart';
import '../../events/presentation/event_editor_sheet.dart';
import '../../events/presentation/event_list_tile.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../data/author_auth_provider.dart';
import '../data/own_events_provider.dart';
import 'author_change_password_screen.dart';
import 'author_dashboard_stats.dart';
import 'author_login_screen.dart';
import 'stale_events_screen.dart';

class AuthorScreen extends ConsumerWidget {
  const AuthorScreen({super.key});

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? existingEvent,
    Map<String, dynamic>? existingDraft,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'EventEditorPage'),
        builder: (context) => EventEditorPage(
          existingEvent: existingEvent,
          existingDraft: existingDraft,
        ),
      ),
    );
    if (result == true) {
      ref.invalidate(ownEventsProvider);
      ref.invalidate(ownDraftsProvider);
      // Haelt die oeffentliche Events-Liste (Hive-Cache) sofort aktuell,
      // statt auf die Sync-Drossel zu warten.
      await ref.read(sync_service.syncServiceProvider).syncEvents(force: true);
    }
  }

  Future<void> _deleteDraft(
      BuildContext context, WidgetRef ref, int draftId) async {
    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .deleteDraft(token: token, draftId: draftId),
          );
      ref.invalidate(ownDraftsProvider);
    } catch (error) {
      if (context.mounted) showErrorToast(ref, describeRemoteError(error));
    }
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(ownEventsProvider);
    ref.invalidate(ownDraftsProvider);
    await Future.wait([
      ref.read(ownEventsProvider.future),
      ref.read(ownDraftsProvider.future),
    ]);
  }

  List<StatTile> _buildStatTiles(
      BuildContext context, AuthorDashboardStats stats) {
    return [
      StatTile(
          icon: Icons.public,
          value: '${stats.onlineCount}',
          label: 'Events online'),
      StatTile(
          icon: Icons.calendar_month,
          value: '${stats.thisMonthCount}',
          label: 'Diesen Monat'),
      StatTile(
        icon: Icons.warning_amber,
        value: '${stats.staleCount}',
        label: 'Lange kein Update',
        color:
            stats.staleCount > 0 ? Theme.of(context).colorScheme.error : null,
        onTap: stats.staleCount == 0
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'StaleEventsScreen'),
                    builder: (context) =>
                        StaleEventsScreen(events: stats.staleEvents),
                  ),
                ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authorAuthProvider);
    final layerNamesById = ref.watch(layerNamesByIdProvider);
    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Autor')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'AuthorLoginScreen'),
                  builder: (context) => const AuthorLoginScreen(),
                ),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('Autoren-Login'),
          ),
        ),
      );
    }

    if (auth.requiresPasswordChange) {
      return Scaffold(
        appBar: AppBar(title: const Text('Autor')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  settings:
                      const RouteSettings(name: 'AuthorChangePasswordScreen'),
                  builder: (context) => const AuthorChangePasswordScreen(),
                ),
              );
              await ref.read(authorAuthProvider.notifier).refreshSession();
            },
            icon: const Icon(Icons.password),
            label: const Text('Passwort ändern'),
          ),
        ),
      );
    }

    final eventsAsync = ref.watch(ownEventsProvider);
    final draftsAsync = ref.watch(ownDraftsProvider);

    Widget body;
    if (eventsAsync.isLoading || draftsAsync.isLoading) {
      body = const SkeletonCardList();
    } else if (eventsAsync.hasError) {
      body = ListView(children: [
        Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${eventsAsync.error}')),
      ]);
    } else if (draftsAsync.hasError) {
      body = ListView(children: [
        Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${draftsAsync.error}')),
      ]);
    } else {
      final events = eventsAsync.value ?? <Map<String, dynamic>>[];
      final drafts = draftsAsync.value ?? <Map<String, dynamic>>[];
      final stats = AuthorDashboardStats.fromEvents(events);

      body = ListView(
        children: [
          DashboardStatRow(tiles: _buildStatTiles(context, stats)),
          if (events.isEmpty && drafts.isEmpty)
            EmptyState(
              icon: Icons.event_note,
              message: 'Noch keine eigenen Events vorhanden.',
              actionLabel: 'Erstes Event erstellen',
              onAction: () => _openForm(context, ref),
            )
          else ...[
            if (events.isNotEmpty)
              ExpansionTile(
                title: Text('Eigene Events (${events.length})'),
                initiallyExpanded: false,
                children: [
                  for (final event in events)
                    EventListTile(
                      title: event['title'] as String? ?? '',
                      location: event['locationAddress'] as String?,
                      layerName:
                          layerNamesById[(event['layerId'] as num?)?.toInt()] ??
                              'Kein DV',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            settings:
                                const RouteSettings(name: 'EventDetailScreen'),
                            builder: (context) =>
                                EventDetailScreen(event: event),
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (drafts.isNotEmpty)
              ExpansionTile(
                title: Text('Entwürfe (${drafts.length})'),
                initiallyExpanded: false,
                children: [
                  for (final draft in drafts)
                    EventListTile(
                      title: draft['title'] as String? ?? '',
                      location: draft['locationAddress'] as String?,
                      layerName:
                          layerNamesById[(draft['layerId'] as num?)?.toInt()] ??
                              'Kein DV',
                      onEdit: () =>
                          _openForm(context, ref, existingDraft: draft),
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Entwurf löschen'),
                            content: const Text(
                                'Möchtest du diesen Entwurf löschen?'),
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
                          if (!context.mounted) return;
                          await _deleteDraft(
                              context, ref, (draft['id'] as num).toInt());
                        }
                      },
                    ),
                ],
              ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meine Events')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: body,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Weiteres Event erstellen'),
      ),
    );
  }
}
