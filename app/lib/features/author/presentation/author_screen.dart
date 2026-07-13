import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOwnEvents());
  }

  Future<void> _loadOwnEvents() async {
    final auth = ref.read(authorAuthProvider);
    if (!auth.isLoggedIn || auth.isLocked || auth.requiresPasswordChange) {
      if (!mounted) return;
      setState(() {
        _events = <Map<String, dynamic>>[];
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
      final events = await remote.fetchOwnEvents(token: token);
      if (!mounted) return;
      setState(() => _events = events);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existingEvent}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EventEditorPage(existingEvent: existingEvent),
      ),
    );
    if (result == true) {
      await _loadOwnEvents();
    }
  }

  Future<void> _deleteEvent(int eventId) async {
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    await remote.deleteOwnEvent(token: token, eventId: eventId);
    await _loadOwnEvents();
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
              await _loadOwnEvents();
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
              await _loadOwnEvents();
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
              await _loadOwnEvents();
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
        onRefresh: _loadOwnEvents,
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
                : _events.isEmpty
                    ? ListView(children: const [
                        Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Noch keine eigenen Events vorhanden.'))
                      ])
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final eventId = (event['id'] as num).toInt();
                          return EventListTile(
                            title: event['title'] as String? ?? '',
                            location: event['location'] as String? ?? '',
                            dv: event['dv'] as String? ?? '',
                            onEdit: () => _openForm(existingEvent: event),
                            onDelete: () async {
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
                                await _deleteEvent(eventId);
                              }
                            },
                          );
                        },
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
