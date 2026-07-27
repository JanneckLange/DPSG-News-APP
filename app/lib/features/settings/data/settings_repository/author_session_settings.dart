part of '../settings_repository.dart';

mixin _AuthorSessionSettings on _SettingsRepositoryBase {
  String? getLegacyAuthorAuthToken() =>
      _box.get(SettingsKeys.authorAuthTokenKey) as String?;

  Future<void> clearLegacyAuthorAuthToken() async {
    await _box.delete(SettingsKeys.authorAuthTokenKey);
  }

  int? getAuthorId() => _box.get(SettingsKeys.authorIdKey) as int?;

  String? getAuthorUsername() =>
      _box.get(SettingsKeys.authorUsernameKey) as String?;

  bool getAuthorIsAdmin() =>
      _box.get(SettingsKeys.authorIsAdminKey, defaultValue: false) as bool;

  bool getAuthorRequiresPasswordChange() => _box.get(
        SettingsKeys.authorRequiresPasswordChangeKey,
        defaultValue: false,
      ) as bool;

  DateTime? getAuthorLastBackgroundedAt() {
    final raw = _box.get(SettingsKeys.authorLastBackgroundedAtKey) as String?;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<void> setAuthorLastBackgroundedAt(DateTime? value) async {
    if (value == null) {
      await _box.delete(SettingsKeys.authorLastBackgroundedAtKey);
      return;
    }
    await _box.put(
        SettingsKeys.authorLastBackgroundedAtKey, value.toUtc().toIso8601String());
  }

  List<int> getAuthorLayerGrantIds() {
    final raw = _box.get(SettingsKeys.authorLayerGrantIdsKey) as List<dynamic>?;
    if (raw == null) return <int>[];
    return raw.whereType<num>().map((value) => value.toInt()).toList();
  }

  List<int> getAuthorTopicGrantIds() {
    final raw = _box.get(SettingsKeys.authorTopicGrantIdsKey) as List<dynamic>?;
    if (raw == null) return <int>[];
    return raw.whereType<num>().map((value) => value.toInt()).toList();
  }

  Future<void> saveAuthorSession({
    required int authorId,
    required String username,
    required bool isAdmin,
    required bool requiresPasswordChange,
    List<int> layerGrantIds = const <int>[],
    List<int> topicGrantIds = const <int>[],
  }) async {
    await Future.wait([
      _box.put(SettingsKeys.authorIdKey, authorId),
      _box.put(SettingsKeys.authorUsernameKey, username),
      _box.put(SettingsKeys.authorIsAdminKey, isAdmin),
      _box.put(SettingsKeys.authorRequiresPasswordChangeKey, requiresPasswordChange),
      _box.put(SettingsKeys.authorLayerGrantIdsKey, layerGrantIds),
      _box.put(SettingsKeys.authorTopicGrantIdsKey, topicGrantIds),
      _box.delete(SettingsKeys.authorLastBackgroundedAtKey),
    ]);
  }

  Future<void> setAuthorRequiresPasswordChange(bool value) async {
    await _box.put(SettingsKeys.authorRequiresPasswordChangeKey, value);
  }

  Future<void> setAuthorIsAdmin(bool value) async {
    await _box.put(SettingsKeys.authorIsAdminKey, value);
  }

  Future<void> setAuthorGrants({
    required List<int> layerGrantIds,
    required List<int> topicGrantIds,
  }) async {
    await Future.wait([
      _box.put(SettingsKeys.authorLayerGrantIdsKey, layerGrantIds),
      _box.put(SettingsKeys.authorTopicGrantIdsKey, topicGrantIds),
    ]);
  }

  Future<void> clearAuthorSession() async {
    await Future.wait([
      _box.delete(SettingsKeys.authorAuthTokenKey),
      _box.delete(SettingsKeys.authorIdKey),
      _box.delete(SettingsKeys.authorUsernameKey),
      _box.delete(SettingsKeys.authorIsAdminKey),
      _box.delete(SettingsKeys.authorRequiresPasswordChangeKey),
      _box.delete(SettingsKeys.authorLayerGrantIdsKey),
      _box.delete(SettingsKeys.authorTopicGrantIdsKey),
      _box.delete(SettingsKeys.authorLastBackgroundedAtKey),
    ]);
  }
}
