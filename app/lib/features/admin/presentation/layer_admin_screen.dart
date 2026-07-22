import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../settings/domain/layer_model.dart';
import '../domain/topic_model.dart';
import 'admin_otp_dialog.dart';
import 'widgets/layer_multi_select_dialog.dart';
import 'widgets/topic_multi_select_dialog.dart';

class LayerAdminScreen extends ConsumerStatefulWidget {
  const LayerAdminScreen({super.key});

  @override
  ConsumerState<LayerAdminScreen> createState() => _LayerAdminScreenState();
}

class _LayerAdminScreenState extends ConsumerState<LayerAdminScreen> {
  List<LayerModel> _layers = <LayerModel>[];
  bool _loadingLayers = true;
  String? _layersError;
  int _layersRequestId = 0;

  int? _selectedLayerId;
  List<TopicModel> _topics = <TopicModel>[];
  bool _loadingTopics = false;
  String? _topicsError;
  int _topicsRequestId = 0;

  final Set<int> _expanded = <int>{};

  @override
  void initState() {
    super.initState();
    _loadLayers();
  }

  Future<void> _loadLayers() async {
    final requestId = ++_layersRequestId;
    setState(() {
      _loadingLayers = true;
      _layersError = null;
    });

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (!mounted || requestId != _layersRequestId) return;
    if (token == null) {
      setState(() {
        _loadingLayers = false;
        _layersError = 'Kein Zugriff';
      });
      return;
    }

    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final response = await remote.fetchAdminLayers(token: token);
      final layers =
          List<Map<String, dynamic>>.from(response['layers'] as List<dynamic>)
              .map(LayerModel.fromJson)
              .toList();
      if (!mounted || requestId != _layersRequestId) return;
      setState(() {
        _layers = layers;
        _expanded.addAll(layers.map((layer) => layer.id));
      });
    } catch (error) {
      if (!mounted || requestId != _layersRequestId) return;
      setState(() => _layersError = error.toString());
    } finally {
      if (mounted && requestId == _layersRequestId) {
        setState(() => _loadingLayers = false);
      }
    }
  }

  Map<int, List<LayerModel>> get _childrenByParentId {
    final map = <int, List<LayerModel>>{};
    for (final layer in _layers) {
      final parentId = layer.parentId;
      if (parentId == null) continue;
      map.putIfAbsent(parentId, () => <LayerModel>[]).add(layer);
    }
    return map;
  }

  List<LayerModel> get _rootLayers {
    final ids = _layers.map((layer) => layer.id).toSet();
    return _layers
        .where(
            (layer) => layer.parentId == null || !ids.contains(layer.parentId))
        .toList();
  }

  Future<void> _onLayerSelected(int layerId) async {
    setState(() => _selectedLayerId = layerId);
    await _loadTopics(layerId);
  }

  Future<void> _loadTopics(int layerId) async {
    final requestId = ++_topicsRequestId;
    setState(() {
      _loadingTopics = true;
      _topicsError = null;
    });

    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final response = await remote.fetchTopics(layerId: layerId);
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

  Future<void> _createChildLayer(int parentId) async {
    final result = await _showLayerFormDialog(title: 'Unterlayer anlegen');
    if (result == null) return;

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.createLayer(
        token: token,
        name: result.name,
        type: result.type,
        parentId: parentId,
        url: result.url,
      );
      setState(() => _expanded.add(parentId));
      await _loadLayers();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Layer konnte nicht angelegt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _createAdmin(int layerId) async {
    final username = await _showNameDialog(
      title: 'Admin anlegen',
      confirmLabel: 'Weiter',
      label: 'Username',
    );
    if (username == null) return;
    if (!mounted) return;

    final selectedLayerIds = await showLayerMultiSelectDialog(
      context,
      layers: _layers,
      initialSelectedIds: {layerId},
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
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Admin konnte nicht angelegt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _createAuthor(int layerId) async {
    final username = await _showNameDialog(
      title: 'Autor anlegen',
      confirmLabel: 'Weiter',
      label: 'Username',
    );
    if (username == null) return;
    if (!mounted) return;

    final selectedLayerIds = await showLayerMultiSelectDialog(
          context,
          layers: _layers,
          initialSelectedIds: {layerId},
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
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Autor konnte nicht angelegt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _renameLayer(LayerModel layer) async {
    final name = await _showNameDialog(
      title: 'Layer umbenennen',
      confirmLabel: 'Speichern',
      initialValue: layer.name,
    );
    if (name == null) return;

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.updateLayer(token: token, layerId: layer.id, name: name);
      await _loadLayers();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Layer konnte nicht umbenannt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _deleteLayer(LayerModel layer) async {
    final confirmed = await _confirm(
      'Layer löschen',
      'Möchtest du den Layer "${layer.name}" löschen?',
      'Löschen',
    );
    if (!confirmed) return;

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.deleteLayer(token: token, layerId: layer.id);
      if (_selectedLayerId == layer.id) {
        setState(() {
          _selectedLayerId = null;
          _topics = <TopicModel>[];
        });
      }
      await _loadLayers();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Layer konnte nicht gelöscht werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _createTopic() async {
    final layerId = _selectedLayerId;
    if (layerId == null) return;

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
      await remote.createTopic(token: token, name: name, layerId: layerId);
      await _loadTopics(layerId);
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
      if (_selectedLayerId != null) {
        await _loadTopics(_selectedLayerId!);
      }
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
      if (_selectedLayerId != null) {
        await _loadTopics(_selectedLayerId!);
      }
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Thema konnte nicht gelöscht werden: ${describeRemoteError(error)}',
      );
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

  Future<_LayerFormResult?> _showLayerFormDialog({required String title}) {
    return showDialog<_LayerFormResult>(
      context: context,
      builder: (context) => _LayerFormDialog(title: title),
    );
  }

  Widget _buildLayerNode(LayerModel layer, {required bool isRoot}) {
    final children = _childrenByParentId[layer.id] ?? const <LayerModel>[];
    final isSelected = _selectedLayerId == layer.id;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Unterlayer anlegen',
          icon: const Icon(Icons.add),
          onPressed: () => _createChildLayer(layer.id),
        ),
        IconButton(
          tooltip: 'Admin anlegen',
          icon: const Icon(Icons.admin_panel_settings),
          onPressed: () => _createAdmin(layer.id),
        ),
        IconButton(
          tooltip: 'Autor anlegen',
          icon: const Icon(Icons.person_add_alt),
          onPressed: () => _createAuthor(layer.id),
        ),
        IconButton(
          tooltip: 'Umbenennen',
          icon: const Icon(Icons.edit),
          onPressed: () => _renameLayer(layer),
        ),
        if (!isRoot)
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteLayer(layer),
          ),
      ],
    );

    if (children.isEmpty) {
      return ListTile(
        selected: isSelected,
        title: Text(layer.name),
        subtitle: Text(layer.type),
        onTap: () => _onLayerSelected(layer.id),
        trailing: actions,
      );
    }

    return ExpansionTile(
      key: PageStorageKey(layer.id),
      initiallyExpanded: _expanded.contains(layer.id),
      onExpansionChanged: (expanded) {
        if (expanded) {
          _expanded.add(layer.id);
        } else {
          _expanded.remove(layer.id);
        }
      },
      title: InkWell(
        onTap: () => _onLayerSelected(layer.id),
        child: Container(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(layer.name),
        ),
      ),
      subtitle: Text(layer.type),
      trailing: actions,
      children: children
          .map((child) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _buildLayerNode(child, isRoot: false),
              ))
          .toList(),
    );
  }

  Widget _buildLayerTree() {
    if (_loadingLayers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_layersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Layer konnten nicht geladen werden: $_layersError'),
        ),
      );
    }
    final roots = _rootLayers;
    if (roots.isEmpty) {
      return const Center(child: Text('Keine Layer vorhanden.'));
    }
    return RefreshIndicator(
      onRefresh: _loadLayers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        children:
            roots.map((root) => _buildLayerNode(root, isRoot: true)).toList(),
      ),
    );
  }

  Widget _buildTopicPanel() {
    if (_selectedLayerId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Layer auswählen, um Themen zu verwalten.'),
        ),
      );
    }
    if (_loadingTopics) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_topicsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Themen konnten nicht geladen werden: $_topicsError'),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Themen',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: _createTopic,
                icon: const Icon(Icons.add),
                label: const Text('Thema anlegen'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _topics.isEmpty
              ? const Center(child: Text('Keine Themen für diesen Layer.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _topics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final topic = _topics[index];
                    return Card(
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
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Layer & Themen verwalten')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          final tree = _buildLayerTree();
          final topicPanel = _buildTopicPanel();
          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 2, child: tree),
                const VerticalDivider(width: 1),
                Expanded(flex: 3, child: topicPanel),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: tree),
              const Divider(height: 1),
              Expanded(child: topicPanel),
            ],
          );
        },
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

class _LayerFormResult {
  const _LayerFormResult({required this.name, required this.type, this.url});

  final String name;
  final String type;
  final String? url;
}

class _LayerFormDialog extends StatefulWidget {
  const _LayerFormDialog({required this.title});

  final String title;

  @override
  State<_LayerFormDialog> createState() => _LayerFormDialogState();
}

class _LayerFormDialogState extends State<_LayerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Bitte einen Namen eingeben.'
                  : null,
            ),
            TextFormField(
              controller: _typeController,
              decoration: const InputDecoration(
                labelText: 'Typ',
                hintText: 'z.B. bezirk, stamm',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Bitte einen Typ eingeben.'
                  : null,
            ),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL (optional)'),
            ),
          ],
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
              final url = _urlController.text.trim();
              Navigator.of(context).pop(_LayerFormResult(
                name: _nameController.text.trim(),
                type: _typeController.text.trim(),
                url: url.isEmpty ? null : url,
              ));
            }
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
