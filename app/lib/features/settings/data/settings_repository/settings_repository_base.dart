part of '../settings_repository.dart';

class _SettingsRepositoryBase {
  _SettingsRepositoryBase(this._box);

  final Box _box;

  List<int> getSelectedLayerIds() {
    final raw = _box.get(SettingsKeys.selectedLayerIdsKey) as List<dynamic>?;
    if (raw == null) return <int>[];
    return raw.whereType<num>().map((value) => value.toInt()).toList();
  }

  Future<void> setSelectedLayerIds(List<int> layerIds) async {
    final currentTopics = getSelectedTopicsByLayer();
    currentTopics.removeWhere((key, _) => !layerIds.contains(key));
    await Future.wait([
      _box.put(SettingsKeys.selectedLayerIdsKey, layerIds),
      _box.put(
        SettingsKeys.selectedLayerTopicsKey,
        currentTopics.map((key, value) => MapEntry(key.toString(), value)),
      ),
    ]);
  }

  List<int> getSelectedTopicIdsForLayer(int layerId) {
    final topicsMap = getSelectedTopicsByLayer();
    return topicsMap[layerId] ?? <int>[];
  }

  Map<int, List<int>> getSelectedTopicsByLayer() {
    final raw =
        _box.get(SettingsKeys.selectedLayerTopicsKey) as Map<dynamic, dynamic>?;
    if (raw == null) return <int, List<int>>{};
    return raw.map<int, List<int>>((key, value) {
      final values = value is List
          ? value.whereType<num>().map((v) => v.toInt()).toList()
          : <int>[];
      return MapEntry(int.parse(key.toString()), values);
    });
  }

  Future<void> setSelectedTopicsForLayer(
      int layerId, List<int> topicIds) async {
    final map = getSelectedTopicsByLayer();
    map[layerId] = topicIds;
    await _box.put(
      SettingsKeys.selectedLayerTopicsKey,
      map.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> removeSelectedTopicsForLayer(int layerId) async {
    final map = getSelectedTopicsByLayer();
    map.remove(layerId);
    await _box.put(
      SettingsKeys.selectedLayerTopicsKey,
      map.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  List<String> getSubscribedTopics() {
    final raw = _box.get(SettingsKeys.subscribedTopicsKey) as List<dynamic>?;
    if (raw == null) return <String>[];
    return raw.whereType<String>().toList();
  }

  Future<void> setSubscribedTopics(List<String> topics) async {
    await _box.put(SettingsKeys.subscribedTopicsKey, topics);
  }

  int? getSelectedLayerId() {
    final layerIds = getSelectedLayerIds();
    return layerIds.isNotEmpty ? layerIds.first : null;
  }

  bool getAuthorMode() =>
      _box.get(SettingsKeys.authorModeKey, defaultValue: false) as bool;

  Future<void> setAuthorMode(bool enabled) async =>
      _box.put(SettingsKeys.authorModeKey, enabled);

  String getAppThemeMode() =>
      _box.get(SettingsKeys.appThemeModeKey, defaultValue: 'system') as String;

  Future<void> setAppThemeMode(String mode) async =>
      _box.put(SettingsKeys.appThemeModeKey, mode);

  bool getAnalyticsTracking() =>
      _box.get(SettingsKeys.analyticsTrackingKey, defaultValue: true) as bool;

  Future<void> setAnalyticsTracking(bool enabled) async =>
      _box.put(SettingsKeys.analyticsTrackingKey, enabled);

  String getAppLanguage() =>
      _box.get(SettingsKeys.appLanguageKey, defaultValue: 'de') as String;

  Future<void> setAppLanguage(String language) async =>
      _box.put(SettingsKeys.appLanguageKey, language);

  bool getHasSeenWelcome() =>
      _box.get(SettingsKeys.hasSeenWelcomeKey, defaultValue: false) as bool;

  Future<void> setHasSeenWelcome(bool value) async =>
      _box.put(SettingsKeys.hasSeenWelcomeKey, value);

  String? getApiBaseUrl() => _box.get(SettingsKeys.apiBaseUrlKey) as String?;

  Future<void> setApiBaseUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _box.delete(SettingsKeys.apiBaseUrlKey);
      return;
    }

    await _box.put(SettingsKeys.apiBaseUrlKey, url.trim());
  }
}
