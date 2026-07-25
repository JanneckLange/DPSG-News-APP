import 'package:flutter/material.dart';

import '../../../../shared/widgets/layer_topic_tree.dart';
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: false,
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: LayerTopicTree(
          layers: widget.layers,
          selectedLayerIds: _selected,
          disableDescendantsOfSelected: widget.disableDescendantsOfSelected,
          onLayerToggled: (id) => setState(() {
            if (!_selected.remove(id)) {
              _selected.add(id);
            }
          }),
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
