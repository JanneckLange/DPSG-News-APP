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
