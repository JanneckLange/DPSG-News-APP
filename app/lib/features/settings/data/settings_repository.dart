import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/services/hive_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(HiveService.getSettingsBox());
});

final authorModeProvider = StateNotifierProvider<AuthorModeNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return AuthorModeNotifier(repository);
});

class AuthorModeNotifier extends StateNotifier<bool> {
  AuthorModeNotifier(this._repository) : super(_repository.getAuthorMode());

  final SettingsRepository _repository;

  Future<void> setAuthorMode(bool enabled) async {
    await _repository.setAuthorMode(enabled);
    state = enabled;
  }
}

class SettingsRepository {
  static const String selectedDvsKey = 'selected_dvs';
  static const String selectedDvTopicsKey = 'selected_dv_topics';
  static const String subscribedTopicsKey = 'subscribed_topics';
  static const String authorModeKey = 'author_mode';
  static const String apiBaseUrlKey = 'api_base_url';
  static const String dvTreeKey = 'dv_tree';
  static const String dvTreeLastChangeKey = 'dv_tree_last_change';

  SettingsRepository(this._box);

  final Box _box;

  List<String> getSelectedDvs() {
    final raw = _box.get(selectedDvsKey) as List<dynamic>?;
    if (raw == null) return <String>[];
    return raw.whereType<String>().toList();
  }

  Future<void> setSelectedDvs(List<String> dvs) async {
    final currentTopics = getSelectedTopicsByDv();
    currentTopics.removeWhere((key, _) => !dvs.contains(key));
    await Future.wait([_box.put(selectedDvsKey, dvs), _box.put(selectedDvTopicsKey, currentTopics)]);
  }

  List<String> getSelectedTopicsForDv(String dv) {
    final topicsMap = getSelectedTopicsByDv();
    return topicsMap[dv] ?? <String>[];
  }

  Map<String, List<String>> getSelectedTopicsByDv() {
    final raw = _box.get(selectedDvTopicsKey) as Map<dynamic, dynamic>?;
    if (raw == null) return <String, List<String>>{};
    return raw.map<String, List<String>>((key, value) {
      final values = value is List ? value.whereType<String>().toList() : <String>[];
      return MapEntry(key as String, values);
    });
  }

  Future<void> setSelectedTopicsForDv(String dv, List<String> topics) async {
    final map = getSelectedTopicsByDv();
    map[dv] = topics;
    await _box.put(selectedDvTopicsKey, map);
  }

  Future<void> removeSelectedTopicsForDv(String dv) async {
    final map = getSelectedTopicsByDv();
    map.remove(dv);
    await _box.put(selectedDvTopicsKey, map);
  }

  List<String> getSubscribedTopics() {
    final raw = _box.get(subscribedTopicsKey) as List<dynamic>?;
    if (raw == null) return <String>[];
    return raw.whereType<String>().toList();
  }

  Future<void> setSubscribedTopics(List<String> topics) async {
    await _box.put(subscribedTopicsKey, topics);
  }

  String? getSelectedDv() {
    final dvs = getSelectedDvs();
    return dvs.isNotEmpty ? dvs.first : null;
  }

  bool getAuthorMode() => _box.get(authorModeKey, defaultValue: false) as bool;

  Future<void> setAuthorMode(bool enabled) async => _box.put(authorModeKey, enabled);

  String? getApiBaseUrl() => _box.get(apiBaseUrlKey) as String?;

  Future<void> setApiBaseUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _box.delete(apiBaseUrlKey);
      return;
    }

    await _box.put(apiBaseUrlKey, url.trim());
  }

  Future<void> setDvTree(List<Map<String, dynamic>> tree, String lastChange) async {
    await _box.put(dvTreeKey, tree);
    await _box.put(dvTreeLastChangeKey, lastChange);
  }

  List<Map<String, dynamic>>? getDvTree() {
    final raw = _box.get(dvTreeKey) as List<dynamic>?;
    if (raw == null) return null;
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String? getDvTreeLastChange() => _box.get(dvTreeLastChangeKey) as String?;
}
