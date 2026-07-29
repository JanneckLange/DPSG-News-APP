import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/error_toast_service.dart';
import '../../../../core/services/sync_service.dart' as sync_service;
import '../../../../shared/utils/date_format_utils.dart';
import '../../../admin/presentation/admin_user_detail_screen.dart';
import '../../../author/data/author_auth_provider.dart';

const Map<String, String> _eventHistoryFieldLabels = {
  'title': 'Titel',
  'description': 'Beschreibung',
  'startDate': 'Start',
  'endDate': 'Ende',
  'locationAddress': 'Adresse',
  'locationLat': 'Breitengrad',
  'locationLng': 'Längengrad',
  'layerId': 'Layer',
  'topicId': 'Thema',
  'cta1Label': 'Button 1 (Text)',
  'cta1Url': 'Button 1 (Link)',
  'cta2Label': 'Button 2 (Text)',
  'cta2Url': 'Button 2 (Link)',
  'isPublic': 'Global bewerben',
  'publishAt': 'Veröffentlichung ab',
  'registrationDeadline': 'Anmeldeschluss',
};

String _fieldLabel(String field) => _eventHistoryFieldLabels[field] ?? field;

String _formatValue(dynamic value) {
  if (value == null) return '–';
  if (value is bool) return value ? 'Ja' : 'Nein';
  return value.toString();
}

/// Zeigt das Aenderungsprotokoll eines Events als Dialog. Aufrufbar fuer
/// alle, die das Event bearbeiten duerfen (Admins und Autoren, serverseitig
/// ueber denselben Scope-Check wie beim Bearbeiten gegatet).
Future<void> showEventHistoryDialog(
  BuildContext context, {
  required int eventId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => EventHistoryDialog(eventId: eventId),
  );
}

class EventHistoryDialog extends ConsumerStatefulWidget {
  const EventHistoryDialog({super.key, required this.eventId});

  final int eventId;

  @override
  ConsumerState<EventHistoryDialog> createState() =>
      _EventHistoryDialogState();
}

class _EventHistoryDialogState extends ConsumerState<EventHistoryDialog> {
  late final Future<List<Map<String, dynamic>>> _historyFuture =
      _loadHistory();

  Future<List<Map<String, dynamic>>> _loadHistory() {
    final token = ref.read(authorAuthProvider).token;
    return ref
        .read(sync_service.remoteEventSourceProvider)
        .fetchEventHistory(eventId: widget.eventId, token: token);
  }

  /// Oeffnet das Nutzerprofil auf einer neuen Seite. Nur fuer Admin-
  /// Betrachter aktiv, da AdminUserDetailScreen Admin-Endpoints (u.a.
  /// fetchAdminUsers) voraussetzt, auf die Autoren keinen Zugriff haben.
  Future<void> _openAuthorProfile(int authorId) async {
    try {
      final users =
          await ref.read(authorAuthProvider.notifier).callAuthenticated(
                (token) => ref
                    .read(sync_service.remoteEventSourceProvider)
                    .fetchAdminUsers(token: token),
              );
      final user = users.firstWhere(
        (u) => (u['id'] as num).toInt() == authorId,
        orElse: () => const <String, dynamic>{},
      );
      if (!mounted) return;
      if (user.isEmpty) {
        showErrorToast(ref, 'Nutzer nicht gefunden');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AdminUserDetailScreen(user: user),
        ),
      );
    } catch (error) {
      if (mounted) showErrorToast(ref, describeRemoteError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authorAuthProvider).isAdmin;
    return AlertDialog(
      title: const Text('Änderungsprotokoll'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Änderungsprotokoll konnte nicht geladen werden.'),
              );
            }
            final entries = snapshot.data ?? const <Map<String, dynamic>>[];
            if (entries.isEmpty) {
              return const Center(
                child: Text('Noch keine Änderungen protokolliert.'),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final authorId = (entry['authorId'] as num?)?.toInt();
                final authorUsername =
                    entry['authorUsername'] as String? ?? 'Unbekannt';
                final createdAt =
                    formatEventDateTime(entry['createdAt'] as String?);
                final changes = List<Map<String, dynamic>>.from(
                    entry['changes'] as List<dynamic>? ??
                        const <dynamic>[]);
                final canOpenProfile = isAdmin && authorId != null;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (canOpenProfile)
                            InkWell(
                              onTap: () => _openAuthorProfile(authorId),
                              child: Text(
                                authorUsername,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      decoration: TextDecoration.underline,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            )
                          else
                            Text(
                              authorUsername,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          Text(
                            ' · $createdAt',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (changes.isEmpty)
                        const Text('Keine Feldänderungen erfasst.')
                      else
                        ...changes.map((change) {
                          final field = change['field'] as String? ?? '';
                          final oldValue = _formatValue(change['oldValue']);
                          final newValue = _formatValue(change['newValue']);
                          return Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                                '${_fieldLabel(field)}: $oldValue → $newValue'),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
