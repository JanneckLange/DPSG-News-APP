import 'package:flutter/material.dart';

import '../../../../shared/widgets/layer_topic_tree.dart';
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: false,
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: LayerTopicTree(
          layers: widget.layers,
          topics: widget.topics,
          selectedLayerIds: _selectedLayerIds,
          selectedTopicIds: _selectedTopicIds,
          onLayerToggled: (id) => setState(() {
            if (!_selectedLayerIds.remove(id)) {
              _selectedLayerIds.add(id);
            }
          }),
          onTopicToggled: (id) => setState(() {
            if (!_selectedTopicIds.remove(id)) {
              _selectedTopicIds.add(id);
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
