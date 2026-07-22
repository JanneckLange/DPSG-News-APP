import 'dart:async';

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
    final editorKey = GlobalKey<DvSelectionEditorState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DVs und Topics'),
        actions: [
          TextButton(
            onPressed: () async {
              await editorKey.currentState?.save();
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: DvSelectionEditor(key: editorKey),
    );
  }
}

class DvSelectionEditor extends ConsumerStatefulWidget {
  const DvSelectionEditor({super.key});

  @override
  ConsumerState<DvSelectionEditor> createState() => DvSelectionEditorState();
}

class DvSelectionEditorState extends ConsumerState<DvSelectionEditor> {
  late final Set<int> _selectedLayerIds;
  late final Map<int, List<String>> _selectedTopicsByLayer;
  final Map<int, List<TopicModel>> _topicsCache = {};
  final Set<int> _loadingTopicsForLayer = {};

  @override
  void initState() {
    super.initState();
    final repository = ref.read(settingsRepositoryProvider);
    _selectedLayerIds = repository.getSelectedLayerIds().toSet();
    _selectedTopicsByLayer = repository.getSelectedTopicsByLayer();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final layerTreeAsync = ref.watch(layerTreeProvider);

    return layerTreeAsync.when(
      data: (layers) {
        final dvs = layers.where((layer) => layer.type == 'dv').toList();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: dvs.length,
          itemBuilder: (context, index) {
            final dv = dvs[index];
            final isSelected = _selectedLayerIds.contains(dv.id);
            final selectedTopics = _selectedTopicsByLayer[dv.id] ?? <String>[];
            final knownEmptyTopics = _topicsCache[dv.id]?.isEmpty ?? false;
            final isLoadingTopics = _loadingTopicsForLayer.contains(dv.id);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: Text(dv.name),
                      subtitle: dv.url != null ? Text(dv.url!) : null,
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedLayerIds.add(dv.id);
                          } else {
                            _selectedLayerIds.remove(dv.id);
                            _selectedTopicsByLayer.remove(dv.id);
                          }
                        });
                      },
                    ),
                    if (isSelected && !knownEmptyTopics)
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, bottom: 4),
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
                                  : () => _openTopicDialog(dv, selectedTopics),
                              child: isLoadingTopics
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Topics wählen'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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

  /// Persistiert die aktuelle Auswahl (DVs und Topics je DV) via SettingsRepository.
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
