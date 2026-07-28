import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../events/presentation/event_detail_screen.dart';
import '../../events/presentation/event_list_tile.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../../settings/domain/layer_model.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../domain/topic_model.dart';
import 'admin_otp_dialog.dart';
import 'widgets/layer_multi_select_dialog.dart';
import 'widgets/layer_topic_grant_tree_dialog.dart';

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
  int _contributionsRequestId = 0;

  List<LayerModel> _availableLayers = <LayerModel>[];
  List<TopicModel> _availableTopics = <TopicModel>[];

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _loadContributions();
    _loadLayerContext();
  }

  List<int> _idsOf(String key) {
    return List<int>.from(
      (_user[key] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => (value as num).toInt()),
    );
  }

  List<int> get _adminLayerIds => _idsOf('adminLayerIds');
  List<int> get _layerGrantIds => _idsOf('layerGrantIds');
  List<int> get _topicGrantIds => _idsOf('topicGrantIds');

  String _layerName(int id) {
    for (final layer in _availableLayers) {
      if (layer.id == id) return layer.name;
    }
    return 'Layer #$id';
  }

  String _topicName(int id) {
    for (final topic in _availableTopics) {
      if (topic.id == id) return topic.name;
    }
    return 'Topic #$id';
  }

  Future<void> _loadLayerContext() async {
    List<LayerModel> layers = <LayerModel>[];
    try {
      final response =
          await ref.read(authorAuthProvider.notifier).callAuthenticated(
                (token) => ref
                    .read(sync_service.remoteEventSourceProvider)
                    .fetchAdminLayers(token: token),
              );
      layers =
          List<Map<String, dynamic>>.from(response['layers'] as List<dynamic>)
              .map(LayerModel.fromJson)
              .toList();
      if (!mounted) return;
      setState(() => _availableLayers = layers);
    } catch (_) {
      // Layer-Namen bleiben dann als "Layer #id" sichtbar.
    }
    // Topics je Layer laden statt global (/api/topics ohne layerId) - der
    // eigene Layer-Zweig aus fetchAdminLayers ist bereits serverseitig
    // gescoped, damit bleiben auch die geladenen Topics auf den eigenen
    // Scope beschraenkt (#113).
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final topics = <TopicModel>[];
      for (final layer in layers) {
        final response = await remote.fetchTopics(layerId: layer.id);
        topics.addAll(
          List<Map<String, dynamic>>.from(response['topics'] as List<dynamic>)
              .map(TopicModel.fromJson),
        );
      }
      if (!mounted) return;
      setState(() => _availableTopics = topics);
    } catch (_) {
      // Topic-Namen bleiben dann als "Topic #id" sichtbar, Baum-Dialog zeigt
      // in diesem Fall keine Topics an.
    }
  }

  Future<void> _reloadUser() async {
    try {
      final users =
          await ref.read(authorAuthProvider.notifier).callAuthenticated(
                (token) => ref
                    .read(sync_service.remoteEventSourceProvider)
                    .fetchAdminUsers(token: token),
              );
      final userId = (_user['id'] as num).toInt();
      final refreshed = users.firstWhere(
        (u) => (u['id'] as num).toInt() == userId,
        orElse: () => _user,
      );
      if (!mounted) return;
      setState(() => _user = Map<String, dynamic>.from(refreshed));
    } catch (_) {
      // Lokaler Stand bleibt erhalten, wenn Reload fehlschlägt.
    }
  }

  Future<void> _addAdminLayers() async {
    final current = _adminLayerIds.toSet();
    final selected = await showLayerMultiSelectDialog(
      context,
      layers: _availableLayers,
      initialSelectedIds: current,
      title: 'Layer für Admin auswählen',
      disableDescendantsOfSelected: true,
    );
    if (selected == null) return;
    final userId = (_user['id'] as num).toInt();
    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
        (token) async {
          final remote = ref.read(sync_service.remoteEventSourceProvider);
          for (final id in selected.difference(current)) {
            await remote.addAdminLayer(
                token: token, userId: userId, layerId: id);
          }
          for (final id in current.difference(selected)) {
            await remote.removeAdminLayer(
                token: token, userId: userId, layerId: id);
          }
        },
      );
      // Admin-Status haengt jetzt am Server automatisch am Layer-Besitz
      // (Promotion/Demotion) - lokalen Stand daher neu laden statt annehmen.
      await _reloadUser();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Layer konnten nicht aktualisiert werden: ${describeRemoteError(error)}',
      );
      await _reloadUser();
    }
  }

  Future<void> _removeAdminLayer(int layerId) async {
    final userId = (_user['id'] as num).toInt();
    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .removeAdminLayer(
                    token: token, userId: userId, layerId: layerId),
          );
      await _reloadUser();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Layer konnte nicht entfernt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _editAuthorGrants() async {
    final currentLayers = _layerGrantIds.toSet();
    final currentTopics = _topicGrantIds.toSet();
    final selection = await showLayerTopicGrantTreeDialog(
      context,
      layers: _availableLayers,
      topics: _availableTopics,
      initialSelectedLayerIds: currentLayers,
      initialSelectedTopicIds: currentTopics,
      title: 'Autoren-Rechte auswählen',
    );
    if (selection == null) return;
    final userId = (_user['id'] as num).toInt();
    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
        (token) async {
          final remote = ref.read(sync_service.remoteEventSourceProvider);
          for (final id in selection.layerIds.difference(currentLayers)) {
            await remote.addAuthorLayerGrant(
                token: token, userId: userId, layerId: id);
          }
          for (final id in currentLayers.difference(selection.layerIds)) {
            await remote.removeAuthorLayerGrant(
                token: token, userId: userId, layerId: id);
          }
          for (final id in selection.topicIds.difference(currentTopics)) {
            await remote.addAuthorTopicGrant(
                token: token, userId: userId, topicId: id);
          }
          for (final id in currentTopics.difference(selection.topicIds)) {
            await remote.removeAuthorTopicGrant(
                token: token, userId: userId, topicId: id);
          }
        },
      );
      // Werden dabei alle Rechte des Nutzers entfernt, deaktiviert der Server
      // das Konto automatisch - lokalen Stand daher neu laden.
      await _reloadUser();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Autoren-Rechte konnten nicht aktualisiert werden: ${describeRemoteError(error)}',
      );
      await _reloadUser();
    }
  }

  Future<void> _removeLayerGrant(int layerId) async {
    final userId = (_user['id'] as num).toInt();
    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .removeAuthorLayerGrant(
                    token: token, userId: userId, layerId: layerId),
          );
      await _reloadUser();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Layer-Recht konnte nicht entfernt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _removeTopicGrant(int topicId) async {
    final userId = (_user['id'] as num).toInt();
    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .removeAuthorTopicGrant(
                    token: token, userId: userId, topicId: topicId),
          );
      await _reloadUser();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Topic-Recht konnte nicht entfernt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Widget _buildGrantSection({
    required String title,
    required List<int> ids,
    required String Function(int id) nameFor,
    required void Function(int id) onRemove,
    required VoidCallback onAdd,
    required String addLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (ids.isEmpty)
              const Text('Keine zugeordnet.', style: TextStyle(fontSize: 12)),
            for (final id in ids)
              Chip(
                label: Text(nameFor(id)),
                onDeleted: () => onRemove(id),
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
      ],
    );
  }

  Widget _buildAuthorGrantsSection() {
    final layerIds = _layerGrantIds;
    final topicIds = _topicGrantIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Autoren-Rechte', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (layerIds.isEmpty && topicIds.isEmpty)
              const Text('Keine zugeordnet.', style: TextStyle(fontSize: 12)),
            for (final id in layerIds)
              Chip(
                label: Text(_layerName(id)),
                onDeleted: () => _removeLayerGrant(id),
              ),
            for (final id in topicIds)
              Chip(
                avatar: const Icon(Icons.topic_outlined, size: 16),
                label: Text(_topicName(id)),
                onDeleted: () => _removeTopicGrant(id),
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _editAuthorGrants,
          icon: const Icon(Icons.add),
          label: const Text('Rechte bearbeiten'),
        ),
      ],
    );
  }

  Widget _buildGrantsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGrantSection(
              title: 'Admin-Rechte',
              ids: _adminLayerIds,
              nameFor: _layerName,
              onRemove: _removeAdminLayer,
              onAdd: _addAdminLayers,
              addLabel: 'Layer hinzufügen',
            ),
            const SizedBox(height: 20),
            _buildAuthorGrantsSection(),
          ],
        ),
      ),
    );
  }

  Future<void> _loadContributions() async {
    final requestId = ++_contributionsRequestId;
    setState(() {
      _loadingContributions = true;
      _error = null;
    });

    try {
      final events =
          await ref.read(authorAuthProvider.notifier).callAuthenticated(
                (token) => ref
                    .read(sync_service.remoteEventSourceProvider)
                    .fetchEvents(token: token),
              );
      final userId = (_user['id'] as num).toInt();
      if (!mounted || requestId != _contributionsRequestId) return;
      setState(() {
        _contributions = events.where((event) {
          final authorId = event['authorId'];
          return authorId is num && authorId.toInt() == userId;
        }).toList();
      });
    } on StateError {
      if (!mounted || requestId != _contributionsRequestId) return;
      setState(() => _error = 'Kein Zugriff');
    } catch (error) {
      if (!mounted || requestId != _contributionsRequestId) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && requestId == _contributionsRequestId) {
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
    final nextActive = !(_user['isActive'] as bool? ?? false);
    await ref.read(authorAuthProvider.notifier).callAuthenticated(
          (token) => ref
              .read(sync_service.remoteEventSourceProvider)
              .setAdminUserActive(
                token: token,
                userId: (_user['id'] as num).toInt(),
                isActive: nextActive,
              ),
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
    final otp = await ref.read(authorAuthProvider.notifier).callAuthenticated(
          (token) => ref
              .read(sync_service.remoteEventSourceProvider)
              .resetAdminUserPassword(
                token: token,
                userId: (_user['id'] as num).toInt(),
              ),
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

    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .deleteAdminUser(
                  token: token,
                  userId: (_user['id'] as num).toInt(),
                ),
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

  Future<void> _openContribution(Map<String, dynamic> event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(event: event),
      ),
    );
    await _loadContributions();
  }

  @override
  Widget build(BuildContext context) {
    final userId = (_user['id'] as num).toInt();
    final isActive = _user['isActive'] as bool? ?? false;
    final isAdmin = _user['isAdmin'] as bool? ?? false;
    final scheme = Theme.of(context).colorScheme;
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
                        if (isAdmin)
                          Chip(
                            label: const Text('Admin'),
                            backgroundColor: scheme.primaryContainer,
                          ),
                        if (_layerGrantIds.isNotEmpty ||
                            _topicGrantIds.isNotEmpty)
                          Chip(
                            label: const Text('Autor'),
                            backgroundColor: scheme.secondaryContainer,
                          ),
                        if (!isActive)
                          Chip(
                            label: const Text('Deaktiviert'),
                            backgroundColor: scheme.errorContainer,
                          ),
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
            _buildGrantsCard(),
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
                  onTap: () => _openContribution(event),
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
