import 'package:flutter/material.dart';

import '../../../settings/domain/layer_model.dart';

/// Zeigt einen Dialog mit dem Layer-Baum als Checkbox-Liste und liefert die
/// vom Nutzer gewaehlten Layer-IDs zurueck (null bei Abbruch).
Future<Set<int>?> showLayerMultiSelectDialog(
  BuildContext context, {
  required List<LayerModel> layers,
  required Set<int> initialSelectedIds,
  String title = 'Layer auswählen',
}) {
  return showDialog<Set<int>>(
    context: context,
    builder: (context) => LayerMultiSelectDialog(
      layers: layers,
      initialSelectedIds: initialSelectedIds,
      title: title,
    ),
  );
}

class LayerMultiSelectDialog extends StatefulWidget {
  const LayerMultiSelectDialog({
    super.key,
    required this.layers,
    required this.initialSelectedIds,
    this.title = 'Layer auswählen',
  });

  final List<LayerModel> layers;
  final Set<int> initialSelectedIds;
  final String title;

  @override
  State<LayerMultiSelectDialog> createState() => _LayerMultiSelectDialogState();
}

class _LayerMultiSelectDialogState extends State<LayerMultiSelectDialog> {
  late final Set<int> _selected = Set<int>.from(widget.initialSelectedIds);
  final Set<int> _expanded = <int>{};

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

  Widget _buildNode(LayerModel layer) {
    final children = _childrenByParentId[layer.id] ?? const <LayerModel>[];
    final checkbox = Checkbox(
      value: _selected.contains(layer.id),
      onChanged: (checked) {
        setState(() {
          if (checked == true) {
            _selected.add(layer.id);
          } else {
            _selected.remove(layer.id);
          }
        });
      },
    );

    if (children.isEmpty) {
      return ListTile(
        leading: checkbox,
        title: Text(layer.name),
        subtitle: Text(layer.type),
        onTap: () => checkbox.onChanged?.call(!_selected.contains(layer.id)),
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
      title: Row(
        children: [
          checkbox,
          Expanded(child: Text(layer.name)),
        ],
      ),
      subtitle: Text(layer.type),
      children: children
          .map((child) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _buildNode(child),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roots = _rootLayers;
    return AlertDialog(
      scrollable: false,
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: roots.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine Layer verfügbar.'),
              )
            : ListView(
                shrinkWrap: true,
                children: roots.map(_buildNode).toList(),
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
