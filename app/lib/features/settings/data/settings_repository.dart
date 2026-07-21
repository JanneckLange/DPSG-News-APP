import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/services/hive_service.dart';
import '../domain/layer_model.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(HiveService.getSettingsBox());
});

final authorModeProvider =
    StateNotifierProvider<AuthorModeNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return AuthorModeNotifier(repository);
});

final appThemeModeProvider =
    StateNotifierProvider<AppThemeModeNotifier, String>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return AppThemeModeNotifier(repository);
});

final analyticsTrackingProvider =
    StateNotifierProvider<AnalyticsTrackingNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return AnalyticsTrackingNotifier(repository);
});

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, String>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return AppLanguageNotifier(repository);
});

final notificationsEnabledProvider =
    StateNotifierProvider<NotificationsEnabledNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return NotificationsEnabledNotifier(repository);
});

final newEventPushEnabledProvider =
    StateNotifierProvider<NewEventPushEnabledNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return NewEventPushEnabledNotifier(repository);
});

final subscribedEventsReminderProvider =
    StateNotifierProvider<SubscribedEventsReminderNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return SubscribedEventsReminderNotifier(repository);
});

final deadlineReminderProvider =
    StateNotifierProvider<DeadlineReminderNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return DeadlineReminderNotifier(repository);
});

final weeklyPushSummaryProvider =
    StateNotifierProvider<WeeklyPushSummaryNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return WeeklyPushSummaryNotifier(repository);
});

final savedEventIdsProvider =
    StateNotifierProvider<SavedEventIdsNotifier, Set<String>>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return SavedEventIdsNotifier(repository);
});

final autoSaveEventOnCtaClickProvider =
    StateNotifierProvider<AutoSaveEventOnCtaClickNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return AutoSaveEventOnCtaClickNotifier(repository);
});

final subscribedEventsReminderDaysBeforeProvider =
    StateNotifierProvider<SubscribedEventsReminderDaysBeforeNotifier, int>(
        (ref) {
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
  AnalyticsTrackingNotifier(this._repository)
      : super(_repository.getAnalyticsTracking());

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
  NotificationsEnabledNotifier(this._repository)
      : super(_repository.getNotificationsEnabled());

  final SettingsRepository _repository;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _repository.setNotificationsEnabled(enabled);
    state = enabled;
  }
}

class NewEventPushEnabledNotifier extends StateNotifier<bool> {
  NewEventPushEnabledNotifier(this._repository)
      : super(_repository.getNewEventPushEnabled());

  final SettingsRepository _repository;

  Future<void> setNewEventPushEnabled(bool enabled) async {
    await _repository.setNewEventPushEnabled(enabled);
    state = enabled;
  }
}

class SubscribedEventsReminderNotifier extends StateNotifier<bool> {
  SubscribedEventsReminderNotifier(this._repository)
      : super(_repository.getSubscribedEventsReminderEnabled());

  final SettingsRepository _repository;

  Future<void> setSubscribedEventsReminderEnabled(bool enabled) async {
    await _repository.setSubscribedEventsReminderEnabled(enabled);
    state = enabled;
  }
}

class DeadlineReminderNotifier extends StateNotifier<bool> {
  DeadlineReminderNotifier(this._repository)
      : super(_repository.getDeadlineReminderEnabled());

  final SettingsRepository _repository;

  Future<void> setDeadlineReminderEnabled(bool enabled) async {
    await _repository.setDeadlineReminderEnabled(enabled);
    state = enabled;
  }
}

class WeeklyPushSummaryNotifier extends StateNotifier<bool> {
  WeeklyPushSummaryNotifier(this._repository)
      : super(_repository.getWeeklyPushSummaryEnabled());

  final SettingsRepository _repository;

  Future<void> setWeeklyPushSummaryEnabled(bool enabled) async {
    await _repository.setWeeklyPushSummaryEnabled(enabled);
    state = enabled;
  }
}

class SavedEventIdsNotifier extends StateNotifier<Set<String>> {
  SavedEventIdsNotifier(this._repository)
      : super(_repository.getSavedEventIds().toSet());

  final SettingsRepository _repository;

  Future<void> addEvent(String eventId) async {
    final updated = {...state, eventId};
    await _repository.setSavedEventIds(updated.toList());
    state = updated;
  }

  Future<void> removeEvent(String eventId) async {
    final updated = {...state}..remove(eventId);
    await _repository.setSavedEventIds(updated.toList());
    state = updated;
  }
}

class AutoSaveEventOnCtaClickNotifier extends StateNotifier<bool> {
  AutoSaveEventOnCtaClickNotifier(this._repository)
      : super(_repository.getAutoSaveEventOnCtaClick());

  final SettingsRepository _repository;

  Future<void> setAutoSaveEventOnCtaClick(bool enabled) async {
    await _repository.setAutoSaveEventOnCtaClick(enabled);
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

  static const String selectedLayerIdsKey = 'selected_layer_ids';
  static const String selectedLayerTopicsKey = 'selected_layer_topics';
  static const String subscribedTopicsKey = 'subscribed_topics';
  static const String authorModeKey = 'author_mode';
  static const String apiBaseUrlKey = 'api_base_url';
  static const String appThemeModeKey = 'app_theme_mode';
  static const String analyticsTrackingKey = 'analytics_tracking';
  static const String appLanguageKey = 'app_language';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String newEventPushEnabledKey = 'new_event_push_enabled';
  static const String savedEventIdsKey = 'saved_event_ids';
  static const String autoSaveEventOnCtaClickKey =
      'auto_save_event_on_cta_click';
  static const String subscribedEventsReminderEnabledKey =
      'subscribed_events_reminder_enabled';
  static const String deadlineReminderEnabledKey = 'deadline_reminder_enabled';
  static const String weeklyPushSummaryEnabledKey =
      'weekly_push_summary_enabled';
  static const String subscribedEventsReminderDaysBeforeKey =
      'subscribed_events_reminder_days_before';
  static const String deadlineReminderDaysBeforeKey =
      'deadline_reminder_days_before';
  static const String layerTreeKey = 'layer_tree';
  static const String layerTreeLastChangeKey = 'layer_tree_last_change';
  static const String authorAuthTokenKey =
      'author_auth_token'; // legacy migration key
  static const String authorIdKey = 'author_id';
  static const String authorUsernameKey = 'author_username';
  static const String authorIsAdminKey = 'author_is_admin';
  static const String authorRequiresPasswordChangeKey =
      'author_requires_password_change';
  static const String authorLastBackgroundedAtKey =
      'author_last_backgrounded_at';

  SettingsRepository(this._box);

  final Box _box;

  List<int> getSelectedLayerIds() {
    final raw = _box.get(selectedLayerIdsKey) as List<dynamic>?;
    if (raw == null) return <int>[];
    return raw.whereType<num>().map((value) => value.toInt()).toList();
  }

  Future<void> setSelectedLayerIds(List<int> layerIds) async {
    final currentTopics = getSelectedTopicsByLayer();
    currentTopics.removeWhere((key, _) => !layerIds.contains(key));
    await Future.wait([
      _box.put(selectedLayerIdsKey, layerIds),
      _box.put(
        selectedLayerTopicsKey,
        currentTopics.map((key, value) => MapEntry(key.toString(), value)),
      ),
    ]);
  }

  List<String> getSelectedTopicsForLayer(int layerId) {
    final topicsMap = getSelectedTopicsByLayer();
    return topicsMap[layerId] ?? <String>[];
  }

  Map<int, List<String>> getSelectedTopicsByLayer() {
    final raw = _box.get(selectedLayerTopicsKey) as Map<dynamic, dynamic>?;
    if (raw == null) return <int, List<String>>{};
    return raw.map<int, List<String>>((key, value) {
      final values =
          value is List ? value.whereType<String>().toList() : <String>[];
      return MapEntry(int.parse(key.toString()), values);
    });
  }

  Future<void> setSelectedTopicsForLayer(
      int layerId, List<String> topics) async {
    final map = getSelectedTopicsByLayer();
    map[layerId] = topics;
    await _box.put(
      selectedLayerTopicsKey,
      map.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> removeSelectedTopicsForLayer(int layerId) async {
    final map = getSelectedTopicsByLayer();
    map.remove(layerId);
    await _box.put(
      selectedLayerTopicsKey,
      map.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  List<String> getSubscribedTopics() {
    final raw = _box.get(subscribedTopicsKey) as List<dynamic>?;
    if (raw == null) return <String>[];
    return raw.whereType<String>().toList();
  }

  Future<void> setSubscribedTopics(List<String> topics) async {
    await _box.put(subscribedTopicsKey, topics);
  }

  int? getSelectedLayerId() {
    final layerIds = getSelectedLayerIds();
    return layerIds.isNotEmpty ? layerIds.first : null;
  }

  bool getAuthorMode() => _box.get(authorModeKey, defaultValue: false) as bool;

  Future<void> setAuthorMode(bool enabled) async =>
      _box.put(authorModeKey, enabled);

  String getAppThemeMode() =>
      _box.get(appThemeModeKey, defaultValue: 'system') as String;

  Future<void> setAppThemeMode(String mode) async =>
      _box.put(appThemeModeKey, mode);

  bool getAnalyticsTracking() =>
      _box.get(analyticsTrackingKey, defaultValue: true) as bool;

  Future<void> setAnalyticsTracking(bool enabled) async =>
      _box.put(analyticsTrackingKey, enabled);

  String getAppLanguage() =>
      _box.get(appLanguageKey, defaultValue: 'de') as String;

  Future<void> setAppLanguage(String language) async =>
      _box.put(appLanguageKey, language);

  bool getNotificationsEnabled() =>
      _box.get(notificationsEnabledKey, defaultValue: true) as bool;

  Future<void> setNotificationsEnabled(bool enabled) async =>
      _box.put(notificationsEnabledKey, enabled);

  bool getNewEventPushEnabled() =>
      _box.get(newEventPushEnabledKey, defaultValue: true) as bool;

  Future<void> setNewEventPushEnabled(bool enabled) async =>
      _box.put(newEventPushEnabledKey, enabled);

  bool getSubscribedEventsReminderEnabled() =>
      _box.get(subscribedEventsReminderEnabledKey, defaultValue: true) as bool;

  Future<void> setSubscribedEventsReminderEnabled(bool enabled) async =>
      _box.put(subscribedEventsReminderEnabledKey, enabled);

  bool getDeadlineReminderEnabled() =>
      _box.get(deadlineReminderEnabledKey, defaultValue: true) as bool;

  Future<void> setDeadlineReminderEnabled(bool enabled) async =>
      _box.put(deadlineReminderEnabledKey, enabled);

  bool getWeeklyPushSummaryEnabled() =>
      _box.get(weeklyPushSummaryEnabledKey, defaultValue: true) as bool;

  Future<void> setWeeklyPushSummaryEnabled(bool enabled) async =>
      _box.put(weeklyPushSummaryEnabledKey, enabled);

  List<String> getSavedEventIds() {
    final raw = _box.get(savedEventIdsKey) as List<dynamic>?;
    if (raw == null) return <String>[];
    return raw.whereType<String>().toList();
  }

  Future<void> setSavedEventIds(List<String> eventIds) async {
    await _box.put(savedEventIdsKey, eventIds);
  }

  bool getAutoSaveEventOnCtaClick() =>
      _box.get(autoSaveEventOnCtaClickKey, defaultValue: true) as bool;

  Future<void> setAutoSaveEventOnCtaClick(bool enabled) async {
    await _box.put(autoSaveEventOnCtaClickKey, enabled);
  }

  int getSubscribedEventsReminderDaysBefore() => _normalizeReminderDays(
        _box.get(
          subscribedEventsReminderDaysBeforeKey,
          defaultValue: defaultSubscribedEventsReminderDaysBefore,
        ) as int,
      );

  Future<void> setSubscribedEventsReminderDaysBefore(int days) async => _box
      .put(subscribedEventsReminderDaysBeforeKey, _normalizeReminderDays(days));

  int getDeadlineReminderDaysBefore() => _normalizeReminderDays(
        _box.get(deadlineReminderDaysBeforeKey,
            defaultValue: defaultDeadlineReminderDaysBefore) as int,
      );

  Future<void> setDeadlineReminderDaysBefore(int days) async =>
      _box.put(deadlineReminderDaysBeforeKey, _normalizeReminderDays(days));

  Future<void> resetNotificationSettingsToDefaults(
      {required bool notificationsEnabled}) async {
    await Future.wait([
      _box.put(notificationsEnabledKey, notificationsEnabled),
      _box.put(newEventPushEnabledKey, true),
      _box.put(subscribedEventsReminderEnabledKey, true),
      _box.put(deadlineReminderEnabledKey, true),
      _box.put(weeklyPushSummaryEnabledKey, true),
      _box.put(subscribedEventsReminderDaysBeforeKey,
          defaultSubscribedEventsReminderDaysBefore),
      _box.put(
          deadlineReminderDaysBeforeKey, defaultDeadlineReminderDaysBefore),
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

  Future<void> setLayerTree(List<LayerModel> layers, String lastChange) async {
    await _box.put(
        layerTreeKey, layers.map((layer) => layer.toJson()).toList());
    await _box.put(layerTreeLastChangeKey, lastChange);
  }

  List<LayerModel>? getLayerTree() {
    final raw = _box.get(layerTreeKey) as List<dynamic>?;
    if (raw == null) return null;
    return raw
        .whereType<Map>()
        .map((item) => LayerModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String? getLayerTreeLastChange() =>
      _box.get(layerTreeLastChangeKey) as String?;

  String? getLegacyAuthorAuthToken() => _box.get(authorAuthTokenKey) as String?;

  Future<void> clearLegacyAuthorAuthToken() async {
    await _box.delete(authorAuthTokenKey);
  }

  int? getAuthorId() => _box.get(authorIdKey) as int?;

  String? getAuthorUsername() => _box.get(authorUsernameKey) as String?;

  bool getAuthorIsAdmin() =>
      _box.get(authorIsAdminKey, defaultValue: false) as bool;

  bool getAuthorRequiresPasswordChange() =>
      _box.get(authorRequiresPasswordChangeKey, defaultValue: false) as bool;

  DateTime? getAuthorLastBackgroundedAt() {
    final raw = _box.get(authorLastBackgroundedAtKey) as String?;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<void> setAuthorLastBackgroundedAt(DateTime? value) async {
    if (value == null) {
      await _box.delete(authorLastBackgroundedAtKey);
      return;
    }
    await _box.put(
        authorLastBackgroundedAtKey, value.toUtc().toIso8601String());
  }

  Future<void> saveAuthorSession({
    required int authorId,
    required String username,
    required bool isAdmin,
    required bool requiresPasswordChange,
  }) async {
    await Future.wait([
      _box.put(authorIdKey, authorId),
      _box.put(authorUsernameKey, username),
      _box.put(authorIsAdminKey, isAdmin),
      _box.put(authorRequiresPasswordChangeKey, requiresPasswordChange),
      _box.delete(authorLastBackgroundedAtKey),
    ]);
  }

  Future<void> setAuthorRequiresPasswordChange(bool value) async {
    await _box.put(authorRequiresPasswordChangeKey, value);
  }

  Future<void> setAuthorIsAdmin(bool value) async {
    await _box.put(authorIsAdminKey, value);
  }

  Future<void> clearAuthorSession() async {
    await Future.wait([
      _box.delete(authorAuthTokenKey),
      _box.delete(authorIdKey),
      _box.delete(authorUsernameKey),
      _box.delete(authorIsAdminKey),
      _box.delete(authorRequiresPasswordChangeKey),
      _box.delete(authorLastBackgroundedAtKey),
    ]);
  }
}
