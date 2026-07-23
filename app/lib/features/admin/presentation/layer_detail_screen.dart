import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../settings/domain/layer_model.dart';
import '../domain/topic_model.dart';
import 'admin_otp_dialog.dart';
import 'admin_user_detail_screen.dart';
import 'widgets/layer_multi_select_dialog.dart';
import 'widgets/topic_multi_select_dialog.dart';

class LayerDetailScreen extends ConsumerStatefulWidget {
  const LayerDetailScreen({
    super.key,
    required this.layer,
    required this.allLayers,
  });

  final LayerModel layer;
  final List<LayerModel> allLayers;

  @override
  ConsumerState<LayerDetailScreen> createState() => _LayerDetailScreenState();
}

class _LayerDetailScreenState extends ConsumerState<LayerDetailScreen> {
  List<TopicModel> _topics = <TopicModel>[];
  bool _loadingTopics = true;
  String? _topicsError;
  int _topicsRequestId = 0;

  List<Map<String, dynamic>> _admins = <Map<String, dynamic>>[];
  bool _loadingAdmins = true;
  String? _adminsError;
  int _adminsRequestId = 0;

  List<Map<String, dynamic>> _authors = <Map<String, dynamic>>[];
  bool _loadingAuthors = true;
  String? _authorsError;
  int _authorsRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadTopics();
    _loadAdmins();
    _loadAuthors();
  }

  Future<void> _loadTopics() async {
    final requestId = ++_topicsRequestId;
    setState(() {
      _loadingTopics = true;
      _topicsError = null;
    });
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final response = await remote.fetchTopics(layerId: widget.layer.id);
      final topics =
          List<Map<String, dynamic>>.from(response['topics'] as List<dynamic>)
              .map(TopicModel.fromJson)
              .toList();
      if (!mounted || requestId != _topicsRequestId) return;
      setState(() => _topics = topics);
    } catch (error) {
      if (!mounted || requestId != _topicsRequestId) return;
      setState(() => _topicsError = error.toString());
    } finally {
      if (mounted && requestId == _topicsRequestId) {
        setState(() => _loadingTopics = false);
      }
    }
  }

  Future<void> _loadAdmins() async {
    final requestId = ++_adminsRequestId;
    setState(() {
      _loadingAdmins = true;
      _adminsError = null;
    });
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (!mounted || requestId != _adminsRequestId) return;
    if (token == null) {
      setState(() {
        _loadingAdmins = false;
        _adminsError = 'Kein Zugriff';
      });
      return;
    }
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final admins =
          await remote.fetchLayerAdmins(token: token, layerId: widget.layer.id);
      if (!mounted || requestId != _adminsRequestId) return;
      setState(() => _admins = admins);
    } catch (error) {
      if (!mounted || requestId != _adminsRequestId) return;
      setState(() => _adminsError = error.toString());
    } finally {
      if (mounted && requestId == _adminsRequestId) {
        setState(() => _loadingAdmins = false);
      }
    }
  }

  Future<void> _loadAuthors() async {
    final requestId = ++_authorsRequestId;
    setState(() {
      _loadingAuthors = true;
      _authorsError = null;
    });
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (!mounted || requestId != _authorsRequestId) return;
    if (token == null) {
      setState(() {
        _loadingAuthors = false;
        _authorsError = 'Kein Zugriff';
      });
      return;
    }
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final users = await remote.fetchAdminUsers(token: token);
      final authors = users.where((user) {
        final layerGrantIds = List<int>.from(
          (user['layerGrantIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => (value as num).toInt()),
        );
        return layerGrantIds.contains(widget.layer.id);
      }).toList();
      if (!mounted || requestId != _authorsRequestId) return;
      setState(() => _authors = authors);
    } catch (error) {
      if (!mounted || requestId != _authorsRequestId) return;
      setState(() => _authorsError = error.toString());
    } finally {
      if (mounted && requestId == _authorsRequestId) {
        setState(() => _loadingAuthors = false);
      }
    }
  }

  Future<void> _createTopic() async {
    final name = await _showNameDialog(
      title: 'Thema anlegen',
      confirmLabel: 'Anlegen',
    );
    if (name == null) return;

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.createTopic(token: token, name: name, layerId: widget.layer.id);
      await _loadTopics();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Thema konnte nicht angelegt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _renameTopic(TopicModel topic) async {
    final name = await _showNameDialog(
      title: 'Thema umbenennen',
      confirmLabel: 'Speichern',
      initialValue: topic.name,
    );
    if (name == null) return;

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.updateTopic(token: token, topicId: topic.id, name: name);
      await _loadTopics();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Thema konnte nicht umbenannt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _deleteTopic(TopicModel topic) async {
    final confirmed = await _confirm(
      'Thema löschen',
      'Möchtest du das Thema "${topic.name}" löschen?',
      'Löschen',
    );
    if (!confirmed) return;

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.deleteTopic(token: token, topicId: topic.id);
      await _loadTopics();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Thema konnte nicht gelöscht werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _createAdmin() async {
    final username = await _showNameDialog(
      title: 'Admin anlegen',
      confirmLabel: 'Weiter',
      label: 'Username',
    );
    if (username == null) return;
    if (!mounted) return;

    final selectedLayerIds = await showLayerMultiSelectDialog(
      context,
      layers: widget.allLayers,
      initialSelectedIds: {widget.layer.id},
      title: 'Layer für Admin auswählen',
    );
    if (selectedLayerIds == null || selectedLayerIds.isEmpty) {
      if (mounted) {
        showErrorToast(ref, 'Admin benötigt mindestens einen Layer.');
      }
      return;
    }

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      final response = await remote.createAdminUser(
        token: token,
        username: username,
        isAdmin: true,
        layerIds: selectedLayerIds.toList(),
      );
      if (!mounted) return;
      await showAdminOtpDialog(
        context,
        otp: response['oneTimePassword'] as String,
        title: 'Admin angelegt',
        message: 'Bitte diese Daten jetzt sicher speichern.',
        username: username,
      );
      await _loadAdmins();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Admin konnte nicht angelegt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _createAuthor() async {
    final username = await _showNameDialog(
      title: 'Autor anlegen',
      confirmLabel: 'Weiter',
      label: 'Username',
    );
    if (username == null) return;
    if (!mounted) return;

    final selectedLayerIds = await showLayerMultiSelectDialog(
          context,
          layers: widget.allLayers,
          initialSelectedIds: {widget.layer.id},
          title: 'Layer für Autor auswählen (optional)',
        ) ??
        <int>{};

    Set<int> selectedTopicIds = <int>{};
    if (selectedLayerIds.isNotEmpty) {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final availableTopics = <TopicModel>[];
      for (final id in selectedLayerIds) {
        final response = await remote.fetchTopics(layerId: id);
        availableTopics.addAll(
          List<Map<String, dynamic>>.from(response['topics'] as List<dynamic>)
              .map(TopicModel.fromJson),
        );
      }
      if (availableTopics.isNotEmpty && mounted) {
        selectedTopicIds = await showTopicMultiSelectDialog(
              context,
              title: 'Topics für Autor auswählen (optional)',
              availableTopics: availableTopics,
              initialSelectedTopicIds: const <int>{},
            ) ??
            <int>{};
      }
    }

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      final response = await remote.createAdminUser(
        token: token,
        username: username,
        isAdmin: false,
      );
      final newUserId =
          ((response['author'] as Map<String, dynamic>)['id'] as num).toInt();
      for (final id in selectedLayerIds) {
        await remote.addAuthorLayerGrant(
            token: token, userId: newUserId, layerId: id);
      }
      for (final id in selectedTopicIds) {
        await remote.addAuthorTopicGrant(
            token: token, userId: newUserId, topicId: id);
      }
      if (!mounted) return;
      await showAdminOtpDialog(
        context,
        otp: response['oneTimePassword'] as String,
        title: 'Autor angelegt',
        message: 'Bitte diese Daten jetzt sicher speichern.',
        username: username,
      );
      await _loadAuthors();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Autor konnte nicht angelegt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _openUser(Map<String, dynamic> user, VoidCallback onChanged) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AdminUserDetailScreen(user: user),
      ),
    );
    if (changed == true) {
      onChanged();
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

  Future<String?> _showNameDialog({
    required String title,
    required String confirmLabel,
    String? initialValue,
    String label = 'Name',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
        label: label,
      ),
    );
  }

  Widget _sectionHeader(String title, {required VoidCallback onAdd, required String addLabel}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopicsSection() {
    return [
      _sectionHeader('Themen', onAdd: _createTopic, addLabel: 'Thema anlegen'),
      if (_loadingTopics)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_topicsError != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Themen konnten nicht geladen werden: $_topicsError'),
        )
      else if (_topics.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Keine Themen für diesen Layer.'),
        )
      else
        ..._topics.map((topic) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(topic.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Umbenennen',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _renameTopic(topic),
                    ),
                    IconButton(
                      tooltip: 'Löschen',
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteTopic(topic),
                    ),
                  ],
                ),
              ),
            )),
    ];
  }

  List<Widget> _buildAdminsSection() {
    return [
      _sectionHeader('Admins dieses Layers',
          onAdd: _createAdmin, addLabel: 'Admin anlegen'),
      if (_loadingAdmins)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_adminsError != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Admins konnten nicht geladen werden: $_adminsError'),
        )
      else if (_admins.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Keine Admins für diesen Layer.'),
        )
      else
        ..._admins.map((admin) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(admin['username'] as String? ?? '—'),
                trailing: Chip(
                  label: Text(admin['scope'] == 'direct' ? 'Direkt' : 'Geerbt'),
                ),
                onTap: () => _openUser(admin, _loadAdmins),
              ),
            )),
    ];
  }

  List<Widget> _buildAuthorsSection() {
    return [
      _sectionHeader('Autoren dieses Layers',
          onAdd: _createAuthor, addLabel: 'Autor anlegen'),
      if (_loadingAuthors)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_authorsError != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Autoren konnten nicht geladen werden: $_authorsError'),
        )
      else if (_authors.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Keine Autoren für diesen Layer.'),
        )
      else
        ..._authors.map((author) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(author['username'] as String? ?? '—'),
                onTap: () => _openUser(author, _loadAuthors),
              ),
            )),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.layer.name)),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadTopics(), _loadAdmins(), _loadAuthors()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ..._buildTopicsSection(),
            const Divider(height: 32),
            ..._buildAdminsSection(),
            const Divider(height: 32),
            ..._buildAuthorsSection(),
          ],
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialValue,
    this.label = 'Name',
  });

  final String title;
  final String confirmLabel;
  final String? initialValue;
  final String label;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Bitte einen Wert eingeben.'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
