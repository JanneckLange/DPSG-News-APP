import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../events/presentation/event_editor_sheet.dart';
import '../../events/presentation/event_list_tile.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import 'admin_otp_dialog.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  late Map<String, dynamic> _user;
  List<Map<String, dynamic>> _contributions = <Map<String, dynamic>>[];
  bool _loadingContributions = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _loadContributions();
  }

  Future<void> _loadContributions() async {
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _loadingContributions = false;
        _error = 'Kein Zugriff';
      });
      return;
    }

    setState(() {
      _loadingContributions = true;
      _error = null;
    });

    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final events = await remote.fetchEvents(token: token);
      final userId = (_user['id'] as num).toInt();
      if (!mounted) return;
      setState(() {
        _contributions = events.where((event) {
          final authorId = event['authorId'];
          return authorId is num && authorId.toInt() == userId;
        }).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingContributions = false);
      }
    }
  }

  Future<bool> _confirm(
      String title, String message, String confirmLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _toggleActive() async {
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) {
      return;
    }
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    final nextActive = !(_user['isActive'] as bool? ?? false);
    await remote.setAdminUserActive(
      token: token,
      userId: (_user['id'] as num).toInt(),
      isActive: nextActive,
    );
    if (!mounted) return;
    setState(() {
      _user['isActive'] = nextActive;
    });
  }

  Future<void> _resetPassword() async {
    final confirmed = await _confirm(
      'Passwort zurücksetzen',
      'Für diesen Nutzer ein neues Einmalpasswort erzeugen?',
      'Zurücksetzen',
    );
    if (!confirmed) {
      return;
    }
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) {
      return;
    }
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    final otp = await remote.resetAdminUserPassword(
      token: token,
      userId: (_user['id'] as num).toInt(),
    );
    if (!mounted) return;
    await showAdminOtpDialog(
      context,
      otp: otp,
      title: 'Passwort zurückgesetzt',
      message: 'Das neue Einmalpasswort lautet:',
    );
  }

  Future<void> _deleteUser() async {
    if ((_user['isActive'] as bool? ?? false)) {
      showErrorToast(ref, 'Bitte Nutzer zuerst deaktivieren.');
      return;
    }

    final confirmed = await _confirm(
      'Nutzer löschen',
      'Dieser Nutzer wird endgültig gelöscht. Fortfahren?',
      'Löschen',
    );
    if (!confirmed) {
      return;
    }

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) {
      return;
    }
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.deleteAdminUser(
        token: token,
        userId: (_user['id'] as num).toInt(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Nutzer konnte nicht gelöscht werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _editContribution(Map<String, dynamic> event) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EventEditorPage(existingEvent: event),
      ),
    );
    if (changed == true) {
      await _loadContributions();
    }
  }

  Future<void> _deleteContribution(Map<String, dynamic> event) async {
    final confirmed = await _confirm(
      'Event löschen',
      'Möchtest du dieses Event löschen?',
      'Löschen',
    );
    if (!confirmed) {
      return;
    }
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) {
      return;
    }
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    await remote.deleteEvent(
      token: token,
      eventId: (event['id'] as num).toInt(),
    );
    await _loadContributions();
  }

  @override
  Widget build(BuildContext context) {
    final userId = (_user['id'] as num).toInt();
    final isActive = _user['isActive'] as bool? ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(_user['username'] as String? ?? 'Nutzer')),
      body: RefreshIndicator(
        onRefresh: _loadContributions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user['username'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(isActive ? 'Aktiv' : 'Deaktiviert')),
                        if (_user['isAdmin'] == true)
                          const Chip(label: Text('Admin')),
                        if (_user['requiresPasswordChange'] == true)
                          const Chip(label: Text('Reset offen')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _toggleActive,
                          icon: Icon(
                              isActive ? Icons.toggle_off : Icons.toggle_on),
                          label: Text(isActive ? 'Deaktivieren' : 'Aktivieren'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _resetPassword,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Passwort resetten'),
                        ),
                        if (!isActive)
                          FilledButton.icon(
                            onPressed: _deleteUser,
                            icon: const Icon(Icons.delete),
                            label: const Text('Löschen'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Beiträge von diesem Nutzer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_loadingContributions)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              )
            else if (_contributions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Keine Beiträge gefunden.'),
              )
            else
              ..._contributions.map(
                (event) => EventListTile(
                  title: event['title'] as String? ?? '',
                  location: event['location'] as String? ?? '',
                  layerName: ref.watch(layerNamesByIdProvider)[
                          (event['layerId'] as num?)?.toInt()] ??
                      'Kein DV',
                  onEdit: () => _editContribution(event),
                  onDelete: () => _deleteContribution(event),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Nutzer-ID: $userId',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
