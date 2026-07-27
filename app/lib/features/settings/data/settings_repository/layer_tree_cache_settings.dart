part of '../settings_repository.dart';

mixin _LayerTreeCacheSettings on _SettingsRepositoryBase {
  Future<void> setLayerTree(List<LayerModel> layers, String lastChange) async {
    await _box.put(
        SettingsKeys.layerTreeKey, layers.map((layer) => layer.toJson()).toList());
    await _box.put(SettingsKeys.layerTreeLastChangeKey, lastChange);
  }

  List<LayerModel>? getLayerTree() {
    final raw = _box.get(SettingsKeys.layerTreeKey) as List<dynamic>?;
    if (raw == null) return null;
    return raw
        .whereType<Map>()
        .map((item) => LayerModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String? getLayerTreeLastChange() =>
      _box.get(SettingsKeys.layerTreeLastChangeKey) as String?;
}
