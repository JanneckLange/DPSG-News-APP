import 'dart:async';

import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../admin/domain/topic_model.dart';
import '../data/dv_tree_provider.dart';
import '../data/settings_repository.dart';
import '../domain/layer_model.dart';

class DvSelectionScreen extends StatelessWidget {
  const DvSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DVs und Topics'),
      ),
      body: const DvSelectionEditor(autosave: true),
    );
  }
}

class DvSelectionEditor extends ConsumerStatefulWidget {
  const DvSelectionEditor({super.key, this.autosave = false});

  /// Bei true (Einstellungen-Kontext) wird jede Aenderung sofort persistiert
  /// statt auf einen expliziten Speichern-Aufruf zu warten (Onboarding).
  final bool autosave;

  @override
  ConsumerState<DvSelectionEditor> createState() => DvSelectionEditorState();
}

class DvSelectionEditorState extends ConsumerState<DvSelectionEditor> {
  late final Set<int> _selectedLayerIds;
  late final Map<int, List<String>> _selectedTopicsByLayer;
  final Map<int, List<TopicModel>> _topicsCache = {};
  final Set<int> _loadingTopicsForLayer = {};
  Timer? _autosaveDebounce;
  bool _didAutoExpandRoot = false;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(settingsRepositoryProvider);
    _selectedLayerIds = repository.getSelectedLayerIds().toSet();
    _selectedTopicsByLayer = repository.getSelectedTopicsByLayer();
  }

  @override
  void dispose() {
    if (_autosaveDebounce != null && _autosaveDebounce!.isActive) {
      _autosaveDebounce!.cancel();
      _runDebouncedSideEffects();
    }
    super.dispose();
  }

  Future<List<TopicModel>> _fetchTopicsForLayer(int layerId) async {
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    final response = await remote.fetchTopics(layerId: layerId);
    return List<Map<String, dynamic>>.from(response['topics'] as List<dynamic>)
        .map(TopicModel.fromJson)
        .toList();
  }

  /// Laedt die Topics eines DVs beim Oeffnen des Auswahldialogs (lazy) und
  /// zeigt den Dialog nur an, wenn tatsaechlich Topics vorhanden sind.
  Future<void> _openTopicDialog(LayerModel dv, List<String> currentTopics) async {
    setState(() => _loadingTopicsForLayer.add(dv.id));
    List<TopicModel> topics;
    try {
      topics = await _fetchTopicsForLayer(dv.id);
    } catch (error) {
      if (mounted) {
        showErrorToast(
          ref,
          'Topics für ${dv.name} konnten nicht geladen werden: ${describeRemoteError(error)}',
        );
        setState(() => _loadingTopicsForLayer.remove(dv.id));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _topicsCache[dv.id] = topics;
      _loadingTopicsForLayer.remove(dv.id);
    });
    if (topics.isEmpty) return;

    final updated = await _showTopicDialog(
      context,
      dv.name,
      topics.map((topic) => topic.name).toList(),
      currentTopics,
    );
    if (updated != null && mounted) {
      setState(() => _selectedTopicsByLayer[dv.id] = updated);
      if (widget.autosave) {
        await _persistLayerTopics(dv.id, updated);
        _scheduleDebouncedSideEffects();
      }
    }
  }

  Future<void> _toggleLayer(LayerModel dv, bool checked) async {
    setState(() {
      if (checked) {
        _selectedLayerIds.add(dv.id);
      } else {
        _selectedLayerIds.remove(dv.id);
        _selectedTopicsByLayer.remove(dv.id);
      }
    });
    if (widget.autosave) {
      final repository = ref.read(settingsRepositoryProvider);
      await repository.setSelectedLayerIds(_selectedLayerIds.toList()..sort());
      _scheduleDebouncedSideEffects();
    }
  }

  Future<void> _persistLayerTopics(int layerId, List<String> topics) async {
    final repository = ref.read(settingsRepositoryProvider);
    if (_selectedLayerIds.contains(layerId)) {
      await repository.setSelectedTopicsForLayer(layerId, topics);
    } else {
      await repository.removeSelectedTopicsForLayer(layerId);
    }
  }

  /// Fasst Netzwerk-/Analytics-Seiteneffekte aufeinanderfolgender
  /// Aenderungen zusammen, damit z.B. 5 schnelle Checkbox-Toggles nicht 5
  /// Push-Refreshes und 5 Analytics-Events ausloesen.
  void _scheduleDebouncedSideEffects() {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 500), () {
      _runDebouncedSideEffects();
    });
  }

  void _runDebouncedSideEffects() {
    unawaited(ref.read(notificationServiceProvider).refreshTopicSubscriptions());
    final layerTree = ref.read(layerTreeProvider).asData?.value ?? <LayerModel>[];
    final layerNamesById = {for (final layer in layerTree) layer.id: layer.name};
    final selectedNames = (_selectedLayerIds.toList()..sort())
        .map((id) => layerNamesById[id])
        .whereType<String>()
        .toList()
      ..sort();
    unawaited(
      ref.read(analyticsServiceProvider).trackDvSelectionChanged(selectedNames),
    );
  }

  Map<int, List<LayerModel>> _childrenByParentId(List<LayerModel> layers) {
    final map = <int, List<LayerModel>>{};
    for (final layer in layers) {
      final parentId = layer.parentId;
      if (parentId == null) continue;
      map.putIfAbsent(parentId, () => <LayerModel>[]).add(layer);
    }
    return map;
  }

  List<LayerModel> _rootLayers(List<LayerModel> layers) {
    final ids = layers.map((layer) => layer.id).toSet();
    return layers
        .where(
            (layer) => layer.parentId == null || !ids.contains(layer.parentId))
        .toList();
  }

  TreeNode<LayerModel?> _buildTreeNode(
      LayerModel layer, Map<int, List<LayerModel>> childrenByParentId) {
    final node = TreeNode<LayerModel?>(key: layer.id.toString(), data: layer);
    final children = childrenByParentId[layer.id] ?? const <LayerModel>[];
    for (final child in children) {
      node.add(_buildTreeNode(child, childrenByParentId));
    }
    return node;
  }

  TreeNode<LayerModel?> _buildTree(List<LayerModel> layers) {
    final childrenByParentId = _childrenByParentId(layers);
    final root = TreeNode<LayerModel?>.root(data: null);
    for (final layer in _rootLayers(layers)) {
      root.add(_buildTreeNode(layer, childrenByParentId));
    }
    return root;
  }

  void _onTreeReady(TreeViewController<LayerModel?, TreeNode<LayerModel?>> controller,
      TreeNode<LayerModel?> tree) {
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

    if (layer.type != 'dv') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          layer.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    final isSelected = _selectedLayerIds.contains(layer.id);
    final selectedTopics = _selectedTopicsByLayer[layer.id] ?? <String>[];
    final knownEmptyTopics = _topicsCache[layer.id]?.isEmpty ?? false;
    final isLoadingTopics = _loadingTopicsForLayer.contains(layer.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(layer.name),
            value: isSelected,
            onChanged: (checked) => _toggleLayer(layer, checked == true),
          ),
          if (isSelected && !knownEmptyTopics)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedTopics.isEmpty
                          ? 'Keine spezifischen Topics ausgewählt.'
                          : 'Topics: ${selectedTopics.join(', ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: isLoadingTopics
                        ? null
                        : () => _openTopicDialog(layer, selectedTopics),
                    child: isLoadingTopics
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Topics wählen'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layerTreeAsync = ref.watch(layerTreeProvider);

    return layerTreeAsync.when(
      data: (layers) {
        final tree = _buildTree(layers);
        if (tree.childrenAsList.isEmpty) {
          return const Center(child: Text('Keine DVs verfügbar.'));
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('DV-Liste konnte nicht geladen werden: $error'),
          ),
        );
      },
    );
  }

  /// Persistiert die aktuelle Auswahl (DVs und Topics je DV) via
  /// SettingsRepository. Wird nur im Nicht-Autosave-Kontext (Onboarding)
  /// von aussen aufgerufen.
  Future<List<String>> save() async {
    final repository = ref.read(settingsRepositoryProvider);
    final analytics = ref.read(analyticsServiceProvider);
    final layerTree =
        ref.read(layerTreeProvider).asData?.value ?? <LayerModel>[];
    final selectedLayerIds = _selectedLayerIds.toList()..sort();
    await repository.setSelectedLayerIds(selectedLayerIds);

    for (final layerId in _selectedTopicsByLayer.keys) {
      if (_selectedLayerIds.contains(layerId)) {
        await repository.setSelectedTopicsForLayer(
            layerId, _selectedTopicsByLayer[layerId] ?? <String>[]);
      } else {
        await repository.removeSelectedTopicsForLayer(layerId);
      }
    }

    await ref.read(notificationServiceProvider).refreshTopicSubscriptions();

    final layerNamesById = {
      for (final layer in layerTree) layer.id: layer.name
    };
    final selectedNames = selectedLayerIds
        .map((id) => layerNamesById[id])
        .whereType<String>()
        .toList()
      ..sort();
    unawaited(analytics.trackDvSelectionChanged(selectedNames));

    return selectedNames;
  }

  Future<List<String>?> _showTopicDialog(
    BuildContext context,
    String dvName,
    List<String> availableTopics,
    List<String> currentTopics,
  ) async {
    final selectedTopics = currentTopics.toSet();
    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Topics für $dvName auswählen'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableTopics.length,
                  itemBuilder: (context, index) {
                    final topic = availableTopics[index];
                    final isSelected = selectedTopics.contains(topic);
                    return CheckboxListTile(
                      title: Text(topic),
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedTopics.add(topic);
                          } else {
                            selectedTopics.remove(topic);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, selectedTopics.toList()),
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
