import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../../settings/domain/layer_model.dart';
import '../../domain/topic_model.dart';

/// Ergebnis des kombinierten Layer+Topic-Baum-Dialogs: Layer-Rechte (nicht
/// vererbend) und Topic-Rechte, unabhaengig voneinander waehlbar.
class LayerTopicGrantSelection {
  const LayerTopicGrantSelection({
    required this.layerIds,
    required this.topicIds,
  });

  final Set<int> layerIds;
  final Set<int> topicIds;
}

/// Zeigt einen zusammenhaengenden Baum-Dialog: Layer-Hierarchie mit den
/// Topics je Layer als Kind-Knoten. Layer- und Topic-Rechte sind unabhaengige,
/// nicht vererbende Autoren-Rechte (siehe author_layer_grants/author_topic_grants),
/// daher keine Deaktivierungslogik zwischen Eltern und Kindern.
Future<LayerTopicGrantSelection?> showLayerTopicGrantTreeDialog(
  BuildContext context, {
  required List<LayerModel> layers,
  required List<TopicModel> topics,
  required Set<int> initialSelectedLayerIds,
  required Set<int> initialSelectedTopicIds,
  String title = 'Autoren-Rechte auswählen',
}) {
  return showDialog<LayerTopicGrantSelection>(
    context: context,
    builder: (context) => _LayerTopicGrantTreeDialog(
      layers: layers,
      topics: topics,
      initialSelectedLayerIds: initialSelectedLayerIds,
      initialSelectedTopicIds: initialSelectedTopicIds,
      title: title,
    ),
  );
}

class _TreeEntry {
  const _TreeEntry.layer(this.layer) : topic = null;
  const _TreeEntry.topic(this.topic) : layer = null;

  final LayerModel? layer;
  final TopicModel? topic;
}

class _LayerTopicGrantTreeDialog extends StatefulWidget {
  const _LayerTopicGrantTreeDialog({
    required this.layers,
    required this.topics,
    required this.initialSelectedLayerIds,
    required this.initialSelectedTopicIds,
    required this.title,
  });

  final List<LayerModel> layers;
  final List<TopicModel> topics;
  final Set<int> initialSelectedLayerIds;
  final Set<int> initialSelectedTopicIds;
  final String title;

  @override
  State<_LayerTopicGrantTreeDialog> createState() =>
      _LayerTopicGrantTreeDialogState();
}

class _LayerTopicGrantTreeDialogState
    extends State<_LayerTopicGrantTreeDialog> {
  late final Set<int> _selectedLayerIds =
      Set<int>.from(widget.initialSelectedLayerIds);
  late final Set<int> _selectedTopicIds =
      Set<int>.from(widget.initialSelectedTopicIds);
  bool _didAutoExpandRoot = false;

  Map<int, List<LayerModel>> get _childrenByParentId {
    final map = <int, List<LayerModel>>{};
    for (final layer in widget.layers) {
      final parentId = layer.parentId;
      if (parentId == null) continue;
      map.putIfAbsent(parentId, () => <LayerModel>[]).add(layer);
    }
    return map;
  }

  List<LayerModel> get _rootLayers {
    final ids = widget.layers.map((layer) => layer.id).toSet();
    return widget.layers
        .where(
            (layer) => layer.parentId == null || !ids.contains(layer.parentId))
        .toList();
  }

  Map<int, List<TopicModel>> get _topicsByLayerId {
    final map = <int, List<TopicModel>>{};
    for (final topic in widget.topics) {
      map.putIfAbsent(topic.layerId, () => <TopicModel>[]).add(topic);
    }
    return map;
  }

  TreeNode<_TreeEntry?> _buildLayerNode(
    LayerModel layer,
    Map<int, List<LayerModel>> childrenByParentId,
    Map<int, List<TopicModel>> topicsByLayerId,
  ) {
    final node = TreeNode<_TreeEntry?>(
      key: 'layer-${layer.id}',
      data: _TreeEntry.layer(layer),
    );
    for (final child in childrenByParentId[layer.id] ?? const <LayerModel>[]) {
      node.add(_buildLayerNode(child, childrenByParentId, topicsByLayerId));
    }
    for (final topic in topicsByLayerId[layer.id] ?? const <TopicModel>[]) {
      node.add(TreeNode<_TreeEntry?>(
        key: 'topic-${topic.id}',
        data: _TreeEntry.topic(topic),
      ));
    }
    return node;
  }

  TreeNode<_TreeEntry?> _buildTree() {
    final childrenByParentId = _childrenByParentId;
    final topicsByLayerId = _topicsByLayerId;
    final root = TreeNode<_TreeEntry?>.root(data: null);
    for (final layer in _rootLayers) {
      root.add(_buildLayerNode(layer, childrenByParentId, topicsByLayerId));
    }
    return root;
  }

  void _onTreeReady(
      TreeViewController<_TreeEntry?, TreeNode<_TreeEntry?>> controller,
      TreeNode<_TreeEntry?> tree) {
    if (_didAutoExpandRoot) return;
    _didAutoExpandRoot = true;
    for (final node in tree.childrenAsList.cast<TreeNode<_TreeEntry?>>()) {
      if (node.data?.layer?.parentId == null) {
        controller.expandNode(node);
      }
    }
  }

  Widget _buildRow(TreeNode<_TreeEntry?> node) {
    final entry = node.data;
    if (entry == null) return const SizedBox.shrink();

    if (entry.layer != null) {
      final layer = entry.layer!;
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(layer.name),
        subtitle: Text(layer.type),
        value: _selectedLayerIds.contains(layer.id),
        onChanged: (checked) {
          setState(() {
            if (checked == true) {
              _selectedLayerIds.add(layer.id);
            } else {
              _selectedLayerIds.remove(layer.id);
            }
          });
        },
      );
    }

    final topic = entry.topic!;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(topic.name),
        value: _selectedTopicIds.contains(topic.id),
        onChanged: (checked) {
          setState(() {
            if (checked == true) {
              _selectedTopicIds.add(topic.id);
            } else {
              _selectedTopicIds.remove(topic.id);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tree = _buildTree();
    return AlertDialog(
      scrollable: false,
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: tree.childrenAsList.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine Layer verfügbar.'),
              )
            : TreeView.simpleTyped<_TreeEntry?, TreeNode<_TreeEntry?>>(
                tree: tree,
                shrinkWrap: true,
                showRootNode: false,
                onTreeReady: (controller) => _onTreeReady(controller, tree),
                expansionIndicatorBuilder: (context, node) =>
                    ChevronIndicator.rightDown(
                  tree: node,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(8),
                ),
                builder: (context, node) => _buildRow(node),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            LayerTopicGrantSelection(
              layerIds: _selectedLayerIds,
              topicIds: _selectedTopicIds,
            ),
          ),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
