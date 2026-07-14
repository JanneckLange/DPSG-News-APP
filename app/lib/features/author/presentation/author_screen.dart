import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/error_toast_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../data/author_auth_provider.dart';
import 'author_change_password_screen.dart';
import 'author_login_screen.dart';
import '../../events/presentation/event_editor_sheet.dart';
import '../../events/presentation/event_list_tile.dart';

class AuthorScreen extends ConsumerStatefulWidget {
  const AuthorScreen({super.key});

  @override
  ConsumerState<AuthorScreen> createState() => _AuthorScreenState();
}

class _AuthorScreenState extends ConsumerState<AuthorScreen> {
  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _drafts = <Map<String, dynamic>>[];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOwnData());
  }

  Future<void> _loadOwnData() async {
    final auth = ref.read(authorAuthProvider);
    if (!auth.isLoggedIn || auth.isLocked || auth.requiresPasswordChange) {
      if (!mounted) return;
      setState(() {
        _events = <Map<String, dynamic>>[];
        _drafts = <Map<String, dynamic>>[];
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token =
          await ref.read(authorAuthProvider.notifier).getValidAccessToken();
      if (token == null) {
        throw StateError('Nicht eingeloggt');
      }
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final results = await Future.wait([
        remote.fetchOwnEvents(token: token),
        remote.fetchOwnDrafts(token: token),
      ]);
      if (!mounted) return;
      setState(() {
        _events = results[0];
        _drafts = results[1];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openForm({
    Map<String, dynamic>? existingEvent,
    Map<String, dynamic>? existingDraft,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EventEditorPage(
          existingEvent: existingEvent,
          existingDraft: existingDraft,
        ),
      ),
    );
    if (result == true) {
      await _loadOwnData();
    }
  }

  Future<void> _deleteEvent(int eventId) async {
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.deleteOwnEvent(token: token, eventId: eventId);
      await _loadOwnData();
    } catch (error) {
      if (mounted) showErrorToast(ref, describeRemoteError(error));
    }
  }

  Future<void> _deleteDraft(int draftId) async {
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.deleteDraft(token: token, draftId: draftId);
      await _loadOwnData();
    } catch (error) {
      if (mounted) showErrorToast(ref, describeRemoteError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authorAuthProvider);
    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Autor')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const AuthorLoginScreen()),
              );
              await _loadOwnData();
            },
            icon: const Icon(Icons.login),
            label: const Text('Autoren-Login'),
          ),
        ),
      );
    }

    if (auth.isLocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Autor')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () async {
              await ref.read(authorAuthProvider.notifier).unlock();
              await _loadOwnData();
            },
            icon: const Icon(Icons.lock_open),
            label: const Text('Mit Biometrie entsperren'),
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
                    builder: (context) => const AuthorChangePasswordScreen()),
              );
              await ref.read(authorAuthProvider.notifier).refreshSession();
              await _loadOwnData();
            },
            icon: const Icon(Icons.password),
            label: const Text('Passwort ändern'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Events'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOwnData,
        child: _isLoading
            ? ListView(children: const [
                SizedBox(height: 240),
                Center(child: CircularProgressIndicator())
              ])
            : _error != null
                ? ListView(children: [
                    Padding(
                        padding: const EdgeInsets.all(24), child: Text(_error!))
                  ])
                : (_events.isEmpty && _drafts.isEmpty)
                    ? ListView(children: const [
                        Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Noch keine eigenen Events vorhanden.'))
                      ])
                    : ListView(
                        children: [
                          if (_events.isNotEmpty)
                            ExpansionTile(
                              title: Text('Eigene Events (${_events.length})'),
                              initiallyExpanded: false,
                              children: [
                                for (final event in _events)
                                  EventListTile(
                                    title: event['title'] as String? ?? '',
                                    location: event['location'] as String? ?? '',
                                    dv: event['dv'] as String? ?? '',
                                    onEdit: () =>
                                        _openForm(existingEvent: event),
                                    onDelete: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Event löschen'),
                                          content: const Text(
                                              'Möchtest du dieses Event löschen?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                      context)
                                                  .pop(false),
                                              child: const Text('Abbrechen'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(
                                                      context)
                                                  .pop(true),
                                              child: const Text('Löschen'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await _deleteEvent(
                                            (event['id'] as num).toInt());
                                      }
                                    },
                                  ),
                              ],
                            ),
                          if (_drafts.isNotEmpty)
                            ExpansionTile(
                              title: Text('Entwürfe (${_drafts.length})'),
                              initiallyExpanded: false,
                              children: [
                                for (final draft in _drafts)
                                  EventListTile(
                                    title: draft['title'] as String? ?? '',
                                    location: draft['location'] as String? ?? '',
                                    dv: draft['dv'] as String? ?? '',
                                    onEdit: () =>
                                        _openForm(existingDraft: draft),
                                    onDelete: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Entwurf löschen'),
                                          content: const Text(
                                              'Möchtest du diesen Entwurf löschen?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                      context)
                                                  .pop(false),
                                              child: const Text('Abbrechen'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(
                                                      context)
                                                  .pop(true),
                                              child: const Text('Löschen'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await _deleteDraft(
                                            (draft['id'] as num).toInt());
                                      }
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Weiteres Event erstellen'),
      ),
    );
  }
}
