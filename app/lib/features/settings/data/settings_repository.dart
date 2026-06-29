import 'package:hive/hive.dart';

class SettingsRepository {
  static const String selectedDvKey = 'selected_dv';
  static const String authorModeKey = 'author_mode';
  static const String apiBaseUrlKey = 'api_base_url';

  SettingsRepository(this._box);

  final Box _box;

  String? getSelectedDv() => _box.get(selectedDvKey) as String?;

  Future<void> setSelectedDv(String dv) async => _box.put(selectedDvKey, dv);

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
}
