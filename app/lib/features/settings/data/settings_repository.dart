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

final appThemeModeProvider = StateNotifierProvider<AppThemeModeNotifier, String>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return AppThemeModeNotifier(repository);
});

final analyticsTrackingProvider = StateNotifierProvider<AnalyticsTrackingNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return AnalyticsTrackingNotifier(repository);
});

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, String>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return AppLanguageNotifier(repository);
});

final notificationsEnabledProvider = StateNotifierProvider<NotificationsEnabledNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return NotificationsEnabledNotifier(repository);
});

final newEventPushEnabledProvider = StateNotifierProvider<NewEventPushEnabledNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return NewEventPushEnabledNotifier(repository);
});

final subscribedEventsReminderProvider = StateNotifierProvider<SubscribedEventsReminderNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return SubscribedEventsReminderNotifier(repository);
});

final deadlineReminderProvider = StateNotifierProvider<DeadlineReminderNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return DeadlineReminderNotifier(repository);
});

final weeklyPushSummaryProvider = StateNotifierProvider<WeeklyPushSummaryNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return WeeklyPushSummaryNotifier(repository);
});

final subscribedEventsReminderDaysBeforeProvider =
    StateNotifierProvider<SubscribedEventsReminderDaysBeforeNotifier, int>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return SubscribedEventsReminderDaysBeforeNotifier(repository);
});

final deadlineReminderDaysBeforeProvider =
    StateNotifierProvider<DeadlineReminderDaysBeforeNotifier, int>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return DeadlineReminderDaysBeforeNotifier(repository);
});

class AuthorModeNotifier extends StateNotifier<bool> {
  AuthorModeNotifier(this._repository) : super(_repository.getAuthorMode());

  final SettingsRepository _repository;

  Future<void> setAuthorMode(bool enabled) async {
    await _repository.setAuthorMode(enabled);
    state = enabled;
  }
}

class AppThemeModeNotifier extends StateNotifier<String> {
  AppThemeModeNotifier(this._repository) : super(_repository.getAppThemeMode());

  final SettingsRepository _repository;

  Future<void> setThemeMode(String mode) async {
    await _repository.setAppThemeMode(mode);
    state = mode;
  }
}

class AnalyticsTrackingNotifier extends StateNotifier<bool> {
  AnalyticsTrackingNotifier(this._repository) : super(_repository.getAnalyticsTracking());

  final SettingsRepository _repository;

  Future<void> setAnalyticsTracking(bool enabled) async {
    await _repository.setAnalyticsTracking(enabled);
    state = enabled;
  }
}

class AppLanguageNotifier extends StateNotifier<String> {
  AppLanguageNotifier(this._repository) : super(_repository.getAppLanguage());

  final SettingsRepository _repository;

  Future<void> setAppLanguage(String language) async {
    await _repository.setAppLanguage(language);
    state = language;
  }
}

class NotificationsEnabledNotifier extends StateNotifier<bool> {
  NotificationsEnabledNotifier(this._repository) : super(_repository.getNotificationsEnabled());

  final SettingsRepository _repository;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _repository.setNotificationsEnabled(enabled);
    state = enabled;
  }
}

class NewEventPushEnabledNotifier extends StateNotifier<bool> {
  NewEventPushEnabledNotifier(this._repository) : super(_repository.getNewEventPushEnabled());

  final SettingsRepository _repository;

  Future<void> setNewEventPushEnabled(bool enabled) async {
    await _repository.setNewEventPushEnabled(enabled);
    state = enabled;
  }
}

class SubscribedEventsReminderNotifier extends StateNotifier<bool> {
  SubscribedEventsReminderNotifier(this._repository) : super(_repository.getSubscribedEventsReminderEnabled());

  final SettingsRepository _repository;

  Future<void> setSubscribedEventsReminderEnabled(bool enabled) async {
    await _repository.setSubscribedEventsReminderEnabled(enabled);
    state = enabled;
  }
}

class DeadlineReminderNotifier extends StateNotifier<bool> {
  DeadlineReminderNotifier(this._repository) : super(_repository.getDeadlineReminderEnabled());

  final SettingsRepository _repository;

  Future<void> setDeadlineReminderEnabled(bool enabled) async {
    await _repository.setDeadlineReminderEnabled(enabled);
    state = enabled;
  }
}

class WeeklyPushSummaryNotifier extends StateNotifier<bool> {
  WeeklyPushSummaryNotifier(this._repository) : super(_repository.getWeeklyPushSummaryEnabled());

  final SettingsRepository _repository;

  Future<void> setWeeklyPushSummaryEnabled(bool enabled) async {
    await _repository.setWeeklyPushSummaryEnabled(enabled);
    state = enabled;
  }
}

class SubscribedEventsReminderDaysBeforeNotifier extends StateNotifier<int> {
  SubscribedEventsReminderDaysBeforeNotifier(this._repository)
      : super(_repository.getSubscribedEventsReminderDaysBefore());

  final SettingsRepository _repository;

  Future<void> setSubscribedEventsReminderDaysBefore(int days) async {
    await _repository.setSubscribedEventsReminderDaysBefore(days);
    state = days;
  }
}

class DeadlineReminderDaysBeforeNotifier extends StateNotifier<int> {
  DeadlineReminderDaysBeforeNotifier(this._repository)
      : super(_repository.getDeadlineReminderDaysBefore());

  final SettingsRepository _repository;

  Future<void> setDeadlineReminderDaysBefore(int days) async {
    await _repository.setDeadlineReminderDaysBefore(days);
    state = days;
  }
}

class SettingsRepository {
  static const int defaultSubscribedEventsReminderDaysBefore = 1;
  static const int defaultDeadlineReminderDaysBefore = 2;

  static const String selectedDvsKey = 'selected_dvs';
  static const String selectedDvTopicsKey = 'selected_dv_topics';
  static const String subscribedTopicsKey = 'subscribed_topics';
  static const String authorModeKey = 'author_mode';
  static const String apiBaseUrlKey = 'api_base_url';
  static const String appThemeModeKey = 'app_theme_mode';
  static const String analyticsTrackingKey = 'analytics_tracking';
  static const String appLanguageKey = 'app_language';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String newEventPushEnabledKey = 'new_event_push_enabled';
  static const String subscribedEventsReminderEnabledKey = 'subscribed_events_reminder_enabled';
  static const String deadlineReminderEnabledKey = 'deadline_reminder_enabled';
  static const String weeklyPushSummaryEnabledKey = 'weekly_push_summary_enabled';
  static const String subscribedEventsReminderDaysBeforeKey = 'subscribed_events_reminder_days_before';
  static const String deadlineReminderDaysBeforeKey = 'deadline_reminder_days_before';
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

  String getAppThemeMode() => _box.get(appThemeModeKey, defaultValue: 'system') as String;

  Future<void> setAppThemeMode(String mode) async => _box.put(appThemeModeKey, mode);

  bool getAnalyticsTracking() => _box.get(analyticsTrackingKey, defaultValue: true) as bool;

  Future<void> setAnalyticsTracking(bool enabled) async => _box.put(analyticsTrackingKey, enabled);

  String getAppLanguage() => _box.get(appLanguageKey, defaultValue: 'de') as String;

  Future<void> setAppLanguage(String language) async => _box.put(appLanguageKey, language);

  bool getNotificationsEnabled() => _box.get(notificationsEnabledKey, defaultValue: true) as bool;

  Future<void> setNotificationsEnabled(bool enabled) async => _box.put(notificationsEnabledKey, enabled);

  bool getNewEventPushEnabled() => _box.get(newEventPushEnabledKey, defaultValue: true) as bool;

  Future<void> setNewEventPushEnabled(bool enabled) async => _box.put(newEventPushEnabledKey, enabled);

  bool getSubscribedEventsReminderEnabled() =>
      _box.get(subscribedEventsReminderEnabledKey, defaultValue: true) as bool;

  Future<void> setSubscribedEventsReminderEnabled(bool enabled) async =>
      _box.put(subscribedEventsReminderEnabledKey, enabled);

  bool getDeadlineReminderEnabled() => _box.get(deadlineReminderEnabledKey, defaultValue: true) as bool;

  Future<void> setDeadlineReminderEnabled(bool enabled) async =>
      _box.put(deadlineReminderEnabledKey, enabled);

  bool getWeeklyPushSummaryEnabled() => _box.get(weeklyPushSummaryEnabledKey, defaultValue: true) as bool;

  Future<void> setWeeklyPushSummaryEnabled(bool enabled) async =>
      _box.put(weeklyPushSummaryEnabledKey, enabled);

  int getSubscribedEventsReminderDaysBefore() =>
      _normalizeReminderDays(
        _box.get(
          subscribedEventsReminderDaysBeforeKey,
          defaultValue: defaultSubscribedEventsReminderDaysBefore,
        ) as int,
      );

  Future<void> setSubscribedEventsReminderDaysBefore(int days) async =>
      _box.put(subscribedEventsReminderDaysBeforeKey, _normalizeReminderDays(days));

  int getDeadlineReminderDaysBefore() =>
      _normalizeReminderDays(
        _box.get(deadlineReminderDaysBeforeKey, defaultValue: defaultDeadlineReminderDaysBefore) as int,
      );

  Future<void> setDeadlineReminderDaysBefore(int days) async =>
      _box.put(deadlineReminderDaysBeforeKey, _normalizeReminderDays(days));

  Future<void> resetNotificationSettingsToDefaults({required bool notificationsEnabled}) async {
    await Future.wait([
      _box.put(notificationsEnabledKey, notificationsEnabled),
      _box.put(newEventPushEnabledKey, true),
      _box.put(subscribedEventsReminderEnabledKey, true),
      _box.put(deadlineReminderEnabledKey, true),
      _box.put(weeklyPushSummaryEnabledKey, true),
      _box.put(subscribedEventsReminderDaysBeforeKey, defaultSubscribedEventsReminderDaysBefore),
      _box.put(deadlineReminderDaysBeforeKey, defaultDeadlineReminderDaysBefore),
    ]);
  }

  int _normalizeReminderDays(int days) {
    if (days < 1) return 1;
    if (days > 10) return 10;
    return days;
  }

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
