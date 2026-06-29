import 'package:hive/hive.dart';

class SettingsRepository {
  static const String selectedDvKey = 'selected_dv';
  static const String authorModeKey = 'author_mode';

  SettingsRepository(this._box);

  final Box _box;

  String? getSelectedDv() => _box.get(selectedDvKey) as String?;

  Future<void> setSelectedDv(String dv) async => _box.put(selectedDvKey, dv);

  bool getAuthorMode() => _box.get(authorModeKey, defaultValue: false) as bool;

  Future<void> setAuthorMode(bool enabled) async => _box.put(authorModeKey, enabled);
}
