import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../../shared/widgets/layer_topic_tree.dart';
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

/// Layer, die weder selbst Autoren haben noch einen Nachfahren mit Autoren
/// besitzen, werden aus der Auswahl entfernt (#42/#43): sie koennen nie
/// Inhalte liefern. Layer ohne eigene Autoren, aber mit einem
/// Autoren-Nachfahren, bleiben sichtbar, damit ihre Kinder ihre Einordnung
/// im Baum behalten.
List<LayerModel> _visibleLayers(List<LayerModel> layers) {
  final childrenByParentId = <int, List<LayerModel>>{};
  for (final layer in layers) {
    final parentId = layer.parentId;
    if (parentId == null) continue;
    childrenByParentId.putIfAbsent(parentId, () => <LayerModel>[]).add(layer);
  }

  final hasAuthorDescendantCache = <int, bool>{};
  bool hasAuthorDescendant(int layerId) {
    return hasAuthorDescendantCache.putIfAbsent(layerId, () {
      for (final child in childrenByParentId[layerId] ?? const <LayerModel>[]) {
        if (child.hasAuthors || hasAuthorDescendant(child.id)) return true;
      }
      return false;
    });
  }

  return layers
      .where((layer) => layer.hasAuthors || hasAuthorDescendant(layer.id))
      .toList();
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
  late final Set<int> _selectedTopicIds;
  List<TopicModel> _topics = <TopicModel>[];
  Timer? _autosaveDebounce;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(settingsRepositoryProvider);
    _selectedLayerIds = repository.getSelectedLayerIds().toSet();
    _selectedTopicIds = repository
        .getSelectedTopicsByLayer()
        .values
        .expand((ids) => ids)
        .toSet();
    unawaited(_loadTopics());

    // Ein bereits (lokal) gecachter Layer-Baum kann schon vor dem ersten
    // Build vorliegen -- direkt in die Felder pruenen statt ueber setState
    // (das ist vor initState/dem ersten Build nicht erlaubt). Kuenftige
    // Aenderungen des Baums fängt ref.listen in build() ab.
    final cachedLayers = ref.read(layerTreeProvider).asData?.value;
    if (cachedLayers != null) {
      _removeLayerSelections(_selectedAuthorlessLayerIds(cachedLayers));
    }
  }

  @override
  void dispose() {
    if (_autosaveDebounce != null && _autosaveDebounce!.isActive) {
      _autosaveDebounce!.cancel();
      _runDebouncedSideEffects();
    }
    super.dispose();
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
      // Baum zeigt bei fehlgeschlagenem Laden nur Layer ohne Topic-Kinder.
    }
  }

  void _toggleLayer(int layerId) {
    setState(() {
      if (_selectedLayerIds.remove(layerId)) {
        final topicIdsForLayer = _topics
            .where((topic) => topic.layerId == layerId)
            .map((topic) => topic.id)
            .toSet();
        _selectedTopicIds.removeWhere(topicIdsForLayer.contains);
      } else {
        _selectedLayerIds.add(layerId);
      }
    });
    if (widget.autosave) {
      unawaited(_persistLayerSelection());
      _scheduleDebouncedSideEffects();
    }
  }

  void _toggleTopic(int topicId) {
    setState(() {
      if (!_selectedTopicIds.remove(topicId)) {
        _selectedTopicIds.add(topicId);
      }
    });
    if (widget.autosave) {
      for (final topic in _topics) {
        if (topic.id == topicId) {
          unawaited(_persistTopicsForLayer(topic.layerId));
          break;
        }
      }
      _scheduleDebouncedSideEffects();
    }
  }

  Future<void> _persistLayerSelection() async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setSelectedLayerIds(_selectedLayerIds.toList()..sort());
  }

  /// Bereits ausgewaehlte Layer, die in [layers] als autorenlos gefuehrt
  /// werden (#42/#43) -- Schnittmenge mit der aktuellen Auswahl.
  Set<int> _selectedAuthorlessLayerIds(List<LayerModel> layers) {
    final authorlessIds = layers
        .where((layer) => !layer.hasAuthors)
        .map((layer) => layer.id)
        .toSet();
    return _selectedLayerIds.intersection(authorlessIds);
  }

  /// Entfernt die angegebenen Layer (und ihre Topics) direkt aus den
  /// Auswahl-Feldern, ohne setState -- fuer den Aufruf vor dem ersten Build.
  void _removeLayerSelections(Iterable<int> layerIds) {
    for (final layerId in layerIds) {
      _selectedLayerIds.remove(layerId);
      final topicIdsForLayer = _topics
          .where((topic) => topic.layerId == layerId)
          .map((topic) => topic.id)
          .toSet();
      _selectedTopicIds.removeWhere(topicIdsForLayer.contains);
    }
  }

  /// Entfernt bereits ausgewaehlte Layer, die zwischenzeitlich autorenlos
  /// geworden sind, still aus der Auswahl (#43) -- ohne Rueckmeldung, analog
  /// zum bisherigen Verhalten bei geloeschten Layern.
  void _pruneAuthorlessSelections(List<LayerModel> layers) {
    final toRemove = _selectedAuthorlessLayerIds(layers);
    if (toRemove.isEmpty) return;

    setState(() => _removeLayerSelections(toRemove));
    if (widget.autosave) {
      unawaited(_persistLayerSelection());
    }
  }

  Future<void> _persistTopicsForLayer(int layerId) async {
    final repository = ref.read(settingsRepositoryProvider);
    final idsForLayer = _topics
        .where((topic) =>
            topic.layerId == layerId && _selectedTopicIds.contains(topic.id))
        .map((topic) => topic.id)
        .toList();
    if (_selectedLayerIds.contains(layerId) && idsForLayer.isNotEmpty) {
      await repository.setSelectedTopicsForLayer(layerId, idsForLayer);
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
    unawaited(
        ref.read(notificationServiceProvider).refreshTopicSubscriptions());
    final layerTree =
        ref.read(layerTreeProvider).asData?.value ?? <LayerModel>[];
    final layerNamesById = {
      for (final layer in layerTree) layer.id: layer.name
    };
    final selectedNames = (_selectedLayerIds.toList()..sort())
        .map((id) => layerNamesById[id])
        .whereType<String>()
        .toList()
      ..sort();
    unawaited(
      ref.read(analyticsServiceProvider).trackDvSelectionChanged(selectedNames),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layerTreeAsync = ref.watch(layerTreeProvider);
    ref.listen<AsyncValue<List<LayerModel>>>(layerTreeProvider, (previous, next) {
      final layers = next.asData?.value;
      if (layers != null) _pruneAuthorlessSelections(layers);
    });

    return layerTreeAsync.when(
      data: (layers) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: LayerTopicTree(
            layers: _visibleLayers(layers),
            topics: _topics,
            selectedLayerIds: _selectedLayerIds,
            selectedTopicIds: _selectedTopicIds,
            shrinkWrap: false,
            emptyLabel: 'Keine DVs verfügbar.',
            onLayerToggled: _toggleLayer,
            onTopicToggled: _toggleTopic,
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
  Future<void> save() async {
    final repository = ref.read(settingsRepositoryProvider);
    final analytics = ref.read(analyticsServiceProvider);
    final layerTree =
        ref.read(layerTreeProvider).asData?.value ?? <LayerModel>[];
    final selectedLayerIds = _selectedLayerIds.toList()..sort();
    await repository.setSelectedLayerIds(selectedLayerIds);

    final topicIdsByLayer = <int, List<int>>{};
    for (final topic in _topics) {
      if (_selectedTopicIds.contains(topic.id)) {
        topicIdsByLayer.putIfAbsent(topic.layerId, () => <int>[]).add(topic.id);
      }
    }
    for (final entry in topicIdsByLayer.entries) {
      if (_selectedLayerIds.contains(entry.key)) {
        await repository.setSelectedTopicsForLayer(entry.key, entry.value);
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
  }
}
