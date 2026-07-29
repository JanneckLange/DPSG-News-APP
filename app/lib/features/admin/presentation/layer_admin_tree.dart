import 'dart:async';

import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../settings/domain/layer_model.dart';
import '../domain/topic_model.dart';
import 'layer_detail_screen.dart';

/// Breite, die links fuer den animated_tree_view-Auf-/Zuklapp-Indikator
/// reserviert bleibt, damit unser eigenes InkWell fuer die Navigation diese
/// Flaeche nicht ueberdeckt (sonst wuerde ein Tap auf den Indikator ebenfalls
/// navigieren statt nur auf-/zuzuklappen).
const double _expansionIndicatorWidth = 40;

class LayerAdminTree extends ConsumerStatefulWidget {
  const LayerAdminTree({super.key});

  @override
  ConsumerState<LayerAdminTree> createState() => _LayerAdminTreeState();
}

class _LayerAdminTreeState extends ConsumerState<LayerAdminTree> {
  List<LayerModel> _layers = <LayerModel>[];
  bool _loadingLayers = true;
  String? _layersError;
  int _layersRequestId = 0;
  List<TopicModel> _topics = <TopicModel>[];

  @override
  void initState() {
    super.initState();
    _loadLayers();
    unawaited(_loadTopics());
  }

  Future<void> _loadTopics() async {
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final response = await remote.fetchTopics();
      final topics =
          List<Map<String, dynamic>>.from(response['topics'] as List<dynamic>)
              .map(TopicModel.fromJson)
              .toList();
      if (!mounted) return;
      setState(() => _topics = topics);
    } catch (_) {
      // Sublabel zeigt dann nur die Sub-Layer-Anzahl, keine Topic-Anzahl.
    }
  }

  Future<void> _loadLayers() async {
    final requestId = ++_layersRequestId;
    setState(() {
      _loadingLayers = true;
      _layersError = null;
    });

    try {
      final layers =
          await ref.read(authorAuthProvider.notifier).callAuthenticated(
        (token) async {
          final remote = ref.read(sync_service.remoteEventSourceProvider);
          final response = await remote.fetchAdminLayers(token: token);
          return List<Map<String, dynamic>>.from(
                  response['layers'] as List<dynamic>)
              .map(LayerModel.fromJson)
              .toList();
        },
      );
      if (!mounted || requestId != _layersRequestId) return;
      setState(() => _layers = layers);
    } on StateError {
      if (!mounted || requestId != _layersRequestId) return;
      setState(() => _layersError = 'Kein Zugriff');
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

  void _openLayerDetail(LayerModel layer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'LayerDetailScreen'),
        builder: (context) =>
            LayerDetailScreen(layer: layer, allLayers: _layers),
      ),
    );
  }

  Future<void> _createChildLayer(int parentId) async {
    final result = await _showLayerFormDialog(title: 'Unterlayer anlegen');
    if (result == null) return;

    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) =>
                ref.read(sync_service.remoteEventSourceProvider).createLayer(
                      token: token,
                      name: result.name,
                      parentId: parentId,
                    ),
          );
      await _loadLayers();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Layer konnte nicht angelegt werden: ${describeRemoteError(error)}',
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

    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .updateLayer(token: token, layerId: layer.id, name: name),
          );
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

    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .deleteLayer(token: token, layerId: layer.id),
          );
      await _loadLayers();
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Layer konnte nicht gelöscht werden: ${describeRemoteError(error)}',
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

  TreeNode<LayerModel?> _buildTreeNode(LayerModel layer) {
    final node = TreeNode<LayerModel?>(key: layer.id.toString(), data: layer);
    final children = _childrenByParentId[layer.id] ?? const <LayerModel>[];
    for (final child in children) {
      node.add(_buildTreeNode(child));
    }
    return node;
  }

  TreeNode<LayerModel?> _buildTree() {
    final root = TreeNode<LayerModel?>.root(data: null);
    for (final layer in _rootLayers) {
      root.add(_buildTreeNode(layer));
    }
    return root;
  }

  bool _didAutoExpandRoot = false;

  void _onTreeReady(
      TreeViewController<LayerModel?, TreeNode<LayerModel?>> controller,
      TreeNode<LayerModel?> tree) {
    // Nur beim allerersten Aufbau des Baums automatisch aufklappen: der
    // initiale Flat-List-Aufbau des Packages beruecksichtigt keine vorab
    // gesetzte Expansion, daher muss ueber den Controller expandiert werden.
    if (_didAutoExpandRoot) return;
    _didAutoExpandRoot = true;
    for (final node in tree.childrenAsList.cast<TreeNode<LayerModel?>>()) {
      if (node.data?.parentId == null) {
        controller.expandNode(node);
      }
    }
  }

  Widget _buildLayerRow(TreeNode<LayerModel?> node) {
    final layer = node.data;
    if (layer == null) return const SizedBox.shrink();
    final isRoot = layer.parentId == null;
    final subLayerCount = _childrenByParentId[layer.id]?.length ?? 0;
    final topicCount =
        _topics.where((topic) => topic.layerId == layer.id).length;

    return Row(
      children: [
        const SizedBox(width: _expansionIndicatorWidth),
        Expanded(
          child: InkWell(
            onTap: () => _openLayerDetail(layer),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(layer.name,
                      style: Theme.of(context).textTheme.bodyLarge),
                  Text(
                    '${layer.authorCount ?? 0} Autoren, $subLayerCount Sub-Layer, $topicCount Topics',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Aktionen',
          onSelected: (value) {
            switch (value) {
              case 'rename':
                _renameLayer(layer);
                break;
              case 'add_child':
                _createChildLayer(layer.id);
                break;
              case 'delete':
                _deleteLayer(layer);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
            const PopupMenuItem(
                value: 'add_child', child: Text('Sub-Layer hinzufügen')),
            if (!isRoot)
              const PopupMenuItem(value: 'delete', child: Text('Löschen')),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
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
    if (_rootLayers.isEmpty) {
      return const Center(child: Text('Keine Layer vorhanden.'));
    }
    final tree = _buildTree();
    return RefreshIndicator(
      onRefresh: _loadLayers,
      child: TreeView.simpleTyped<LayerModel?, TreeNode<LayerModel?>>(
        tree: tree,
        showRootNode: false,
        onTreeReady: (controller) => _onTreeReady(controller, tree),
        expansionIndicatorBuilder: (context, node) =>
            ChevronIndicator.rightDown(
          tree: node,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(8),
        ),
        builder: (context, node) => _buildLayerRow(node),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
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
  const _LayerFormResult({required this.name});

  final String name;
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

  @override
  void dispose() {
    _nameController.dispose();
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
              Navigator.of(context).pop(_LayerFormResult(
                name: _nameController.text.trim(),
              ));
            }
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
