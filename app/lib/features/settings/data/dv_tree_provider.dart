import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/data/remote_event_source.dart';
import '../../../core/services/sync_service.dart';
import '../domain/layer_model.dart';
import 'settings_repository.dart' as settings_repo;

final layerTreeProvider =
    StateNotifierProvider<LayerTreeNotifier, AsyncValue<List<LayerModel>>>(
  (ref) {
    final repository = ref.read(settingsRepositoryProvider);
    final remoteSource = ref.read(remoteEventSourceProvider);
    return LayerTreeNotifier(repository, remoteSource);
  },
);

/// Layer-Namen nach id, zum Aufloesen von `layerId` in Anzeige-Widgets.
/// Waehrend der Baum noch laedt oder eine id unbekannt ist, bleibt der
/// entsprechende Eintrag im Map einfach unauffindbar (Aufrufer legen einen
/// Fallback-Text fest).
final layerNamesByIdProvider = Provider<Map<int, String>>((ref) {
  final layers = ref.watch(layerTreeProvider).asData?.value ?? <LayerModel>[];
  return {for (final layer in layers) layer.id: layer.name};
});

class LayerTreeNotifier extends StateNotifier<AsyncValue<List<LayerModel>>> {
  LayerTreeNotifier(this._repository, this._remoteSource)
      : super(const AsyncValue.loading()) {
    _loadTree();
  }

  final settings_repo.SettingsRepository _repository;
  final RemoteEventSource _remoteSource;

  Future<void> _loadTree() async {
    final localTree = _repository.getLayerTree();
    if (localTree != null) {
      state = AsyncValue.data(localTree);
    }

    try {
      final response = await _remoteSource.fetchLayers();
      final lastChange = response['lastChange'] as String? ?? '';
      final layers =
          List<Map<String, dynamic>>.from(response['layers'] as List<dynamic>)
              .map(LayerModel.fromJson)
              .toList();
      final currentVersion = _repository.getLayerTreeLastChange();
      if (currentVersion == null || currentVersion != lastChange) {
        await _repository.setLayerTree(layers, lastChange);
      }
      state = AsyncValue.data(layers);
    } catch (error, stackTrace) {
      if (localTree == null) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }
}
