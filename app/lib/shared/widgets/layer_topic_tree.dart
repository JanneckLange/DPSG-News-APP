import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../features/admin/domain/topic_model.dart';
import '../../features/settings/domain/layer_model.dart';

/// Breite, die links fuer den animated_tree_view-Auf-/Zuklapp-Indikator
/// reserviert bleibt, damit er nicht mit Checkbox/Titel eines Layer-Knotens
/// ueberlappt (der Indikator wird vom Package absolut links positioniert).
const double _expansionIndicatorWidth = 40;

class _TreeEntry {
  const _TreeEntry.layer(this.layer) : topic = null;
  const _TreeEntry.topic(this.topic) : layer = null;

  final LayerModel? layer;
  final TopicModel? topic;
}

/// Gemeinsamer Layer(+Topic)-Baum: Layer-Hierarchie mit Checkbox je Layer,
/// optional inkl. der Topics je Layer als Kind-Knoten. Kontrollierte
/// Komponente -- Auswahl-Zustand liegt beim Aufrufer (Set-Props +
/// Toggle-Callbacks), damit sowohl Modal-Dialoge (Rueckgabewert bei
/// "Speichern") als auch Inline-Editoren mit Autosave (DV-Auswahl) dieselbe
/// Baum-Darstellung nutzen koennen.
class LayerTopicTree extends StatefulWidget {
  const LayerTopicTree({
    super.key,
    required this.layers,
    this.topics = const <TopicModel>[],
    required this.selectedLayerIds,
    this.selectedTopicIds = const <int>{},
    required this.onLayerToggled,
    this.onTopicToggled,
    this.disableDescendantsOfSelected = false,
    this.emptyLabel = 'Keine Layer verfügbar.',
    this.shrinkWrap = true,
  });

  final List<LayerModel> layers;

  /// Topics werden als Kind-Knoten unter ihrem Layer angezeigt. Leer lassen,
  /// wenn nur Layer (ohne Topics) gebraucht werden.
  final List<TopicModel> topics;

  final Set<int> selectedLayerIds;
  final Set<int> selectedTopicIds;

  final ValueChanged<int> onLayerToggled;

  /// Erforderlich, sobald [topics] nicht leer ist.
  final ValueChanged<int>? onTopicToggled;

  /// Wenn true, gelten Sub-Layer eines bereits ausgewaehlten Vorfahren als
  /// mitausgewaehlt und sind nicht mehr einzeln abwaehlbar (Rechte vererben
  /// auf diesem Layer ohnehin). Fuer den Admin-Rechte-Dialog.
  final bool disableDescendantsOfSelected;

  final String emptyLabel;

  /// true (Standard) fuer Einbettung in einen bereits scrollbaren/begrenzten
  /// Container (z.B. AlertDialog-Inhalt). false, wenn der Baum selbst den
  /// verfuegbaren Platz ausfuellen und scrollen soll (z.B. als Scaffold-Body).
  final bool shrinkWrap;

  @override
  State<LayerTopicTree> createState() => _LayerTopicTreeState();
}

class _LayerTopicTreeState extends State<LayerTopicTree> {
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

  Map<int, LayerModel> get _layersById =>
      {for (final layer in widget.layers) layer.id: layer};

  bool _hasSelectedAncestor(LayerModel layer) {
    if (!widget.disableDescendantsOfSelected) return false;
    final byId = _layersById;
    var currentParentId = layer.parentId;
    while (currentParentId != null) {
      final parent = byId[currentParentId];
      if (parent == null) return false;
      if (widget.selectedLayerIds.contains(parent.id)) return true;
      currentParentId = parent.parentId;
    }
    return false;
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
      final disabledByAncestor = _hasSelectedAncestor(layer);
      // Row+SizedBox statt contentPadding: der Auf-/Zuklapp-Indikator wird
      // vom Package per Stack ueber die volle Zeile gelegt und faengt Taps
      // in den ersten _expansionIndicatorWidth px ab. contentPadding
      // verschiebt nur den sichtbaren Inhalt, nicht die Tap-Flaeche des
      // CheckboxListTile -- die bliebe sonst ueber die volle Breite aktiv
      // und wuerde mit dem Indikator um Taps konkurrieren.
      return Row(
        children: [
          const SizedBox(width: _expansionIndicatorWidth),
          Expanded(
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(layer.name),
              value: disabledByAncestor
                  ? true
                  : widget.selectedLayerIds.contains(layer.id),
              onChanged: disabledByAncestor
                  ? null
                  : (checked) => widget.onLayerToggled(layer.id),
            ),
          ),
        ],
      );
    }

    final topic = entry.topic!;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(topic.name),
        value: widget.selectedTopicIds.contains(topic.id),
        onChanged: (checked) => widget.onTopicToggled?.call(topic.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tree = _buildTree();
    if (tree.childrenAsList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(widget.emptyLabel),
      );
    }
    return TreeView.simpleTyped<_TreeEntry?, TreeNode<_TreeEntry?>>(
      tree: tree,
      shrinkWrap: widget.shrinkWrap,
      showRootNode: false,
      onTreeReady: (controller) => _onTreeReady(controller, tree),
      expansionIndicatorBuilder: (context, node) => ChevronIndicator.rightDown(
        tree: node,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(8),
      ),
      builder: (context, node) => _buildRow(node),
    );
  }
}
