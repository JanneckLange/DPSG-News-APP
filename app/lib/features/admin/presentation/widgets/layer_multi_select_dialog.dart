import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../../settings/domain/layer_model.dart';

/// Zeigt einen Dialog mit dem Layer-Baum als Checkbox-Liste und liefert die
/// vom Nutzer gewaehlten Layer-IDs zurueck (null bei Abbruch).
Future<Set<int>?> showLayerMultiSelectDialog(
  BuildContext context, {
  required List<LayerModel> layers,
  required Set<int> initialSelectedIds,
  String title = 'Layer auswählen',
  bool disableDescendantsOfSelected = false,
}) {
  return showDialog<Set<int>>(
    context: context,
    builder: (context) => LayerMultiSelectDialog(
      layers: layers,
      initialSelectedIds: initialSelectedIds,
      title: title,
      disableDescendantsOfSelected: disableDescendantsOfSelected,
    ),
  );
}

class LayerMultiSelectDialog extends StatefulWidget {
  const LayerMultiSelectDialog({
    super.key,
    required this.layers,
    required this.initialSelectedIds,
    this.title = 'Layer auswählen',
    this.disableDescendantsOfSelected = false,
  });

  final List<LayerModel> layers;
  final Set<int> initialSelectedIds;
  final String title;

  /// Wenn true, werden Sub-Layer eines bereits ausgewaehlten Vorfahren
  /// deaktiviert (nicht abwaehlbar dargestellt als bereits mitausgewaehlt),
  /// da Rechte auf diesem Layer ohnehin vererben. Fuer den Admin-Rechte-Dialog.
  final bool disableDescendantsOfSelected;

  @override
  State<LayerMultiSelectDialog> createState() => _LayerMultiSelectDialogState();
}

class _LayerMultiSelectDialogState extends State<LayerMultiSelectDialog> {
  late final Set<int> _selected = Set<int>.from(widget.initialSelectedIds);
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

  Map<int, LayerModel> get _layersById =>
      {for (final layer in widget.layers) layer.id: layer};

  bool _hasSelectedAncestor(LayerModel layer) {
    if (!widget.disableDescendantsOfSelected) return false;
    final byId = _layersById;
    var currentParentId = layer.parentId;
    while (currentParentId != null) {
      final parent = byId[currentParentId];
      if (parent == null) return false;
      if (_selected.contains(parent.id)) return true;
      currentParentId = parent.parentId;
    }
    return false;
  }

  TreeNode<LayerModel?> _buildTreeNode(
      LayerModel layer, Map<int, List<LayerModel>> childrenByParentId) {
    final node = TreeNode<LayerModel?>(key: layer.id.toString(), data: layer);
    for (final child in childrenByParentId[layer.id] ?? const <LayerModel>[]) {
      node.add(_buildTreeNode(child, childrenByParentId));
    }
    return node;
  }

  TreeNode<LayerModel?> _buildTree() {
    final childrenByParentId = _childrenByParentId;
    final root = TreeNode<LayerModel?>.root(data: null);
    for (final layer in _rootLayers) {
      root.add(_buildTreeNode(layer, childrenByParentId));
    }
    return root;
  }

  void _onTreeReady(
      TreeViewController<LayerModel?, TreeNode<LayerModel?>> controller,
      TreeNode<LayerModel?> tree) {
    if (_didAutoExpandRoot) return;
    _didAutoExpandRoot = true;
    for (final node in tree.childrenAsList.cast<TreeNode<LayerModel?>>()) {
      if (node.data?.parentId == null) {
        controller.expandNode(node);
      }
    }
  }

  Widget _buildRow(TreeNode<LayerModel?> node) {
    final layer = node.data;
    if (layer == null) return const SizedBox.shrink();
    final disabledByAncestor = _hasSelectedAncestor(layer);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(layer.name),
      subtitle: Text(layer.type),
      value: disabledByAncestor ? true : _selected.contains(layer.id),
      onChanged: disabledByAncestor
          ? null
          : (checked) {
              setState(() {
                if (checked == true) {
                  _selected.add(layer.id);
                } else {
                  _selected.remove(layer.id);
                }
              });
            },
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
            : TreeView.simpleTyped<LayerModel?, TreeNode<LayerModel?>>(
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
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
