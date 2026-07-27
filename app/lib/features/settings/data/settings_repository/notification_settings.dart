part of '../settings_repository.dart';

mixin _NotificationSettings on _SettingsRepositoryBase {
  bool getNotificationsEnabled() =>
      _box.get(SettingsKeys.notificationsEnabledKey, defaultValue: true)
          as bool;

  Future<void> setNotificationsEnabled(bool enabled) async =>
      _box.put(SettingsKeys.notificationsEnabledKey, enabled);

  bool getNewEventPushEnabled() =>
      _box.get(SettingsKeys.newEventPushEnabledKey, defaultValue: true)
          as bool;

  Future<void> setNewEventPushEnabled(bool enabled) async =>
      _box.put(SettingsKeys.newEventPushEnabledKey, enabled);

  bool getSubscribedEventsReminderEnabled() => _box.get(
        SettingsKeys.subscribedEventsReminderEnabledKey,
        defaultValue: true,
      ) as bool;

  Future<void> setSubscribedEventsReminderEnabled(bool enabled) async =>
      _box.put(SettingsKeys.subscribedEventsReminderEnabledKey, enabled);

  bool getDeadlineReminderEnabled() => _box.get(
        SettingsKeys.deadlineReminderEnabledKey,
        defaultValue: true,
      ) as bool;

  Future<void> setDeadlineReminderEnabled(bool enabled) async =>
      _box.put(SettingsKeys.deadlineReminderEnabledKey, enabled);

  bool getWeeklyPushSummaryEnabled() => _box.get(
        SettingsKeys.weeklyPushSummaryEnabledKey,
        defaultValue: true,
      ) as bool;

  Future<void> setWeeklyPushSummaryEnabled(bool enabled) async =>
      _box.put(SettingsKeys.weeklyPushSummaryEnabledKey, enabled);

  List<String> getSavedEventIds() {
    final raw = _box.get(SettingsKeys.savedEventIdsKey) as List<dynamic>?;
    if (raw == null) return <String>[];
    return raw.whereType<String>().toList();
  }

  Future<void> setSavedEventIds(List<String> eventIds) async {
    await _box.put(SettingsKeys.savedEventIdsKey, eventIds);
  }

  Map<String, DateTime> getEventViewedAt() {
    final raw = _box.get(SettingsKeys.eventViewedAtKey) as Map<dynamic, dynamic>?;
    if (raw == null) return <String, DateTime>{};
    final result = <String, DateTime>{};
    for (final entry in raw.entries) {
      final parsed = DateTime.tryParse(entry.value?.toString() ?? '');
      if (parsed != null) result[entry.key as String] = parsed;
    }
    return result;
  }

  Future<void> setEventViewedAt(Map<String, DateTime> viewedAt) async {
    final serialized = viewedAt.map(
      (key, value) => MapEntry(key, value.toUtc().toIso8601String()),
    );
    await _box.put(SettingsKeys.eventViewedAtKey, serialized);
  }

  bool getAutoSaveEventOnCtaClick() => _box.get(
        SettingsKeys.autoSaveEventOnCtaClickKey,
        defaultValue: true,
      ) as bool;

  Future<void> setAutoSaveEventOnCtaClick(bool enabled) async {
    await _box.put(SettingsKeys.autoSaveEventOnCtaClickKey, enabled);
  }

  int getSubscribedEventsReminderDaysBefore() => _normalizeReminderDays(
        _box.get(
          SettingsKeys.subscribedEventsReminderDaysBeforeKey,
          defaultValue:
              SettingsRepository.defaultSubscribedEventsReminderDaysBefore,
        ) as int,
      );

  Future<void> setSubscribedEventsReminderDaysBefore(int days) async =>
      _box.put(
        SettingsKeys.subscribedEventsReminderDaysBeforeKey,
        _normalizeReminderDays(days),
      );

  int getDeadlineReminderDaysBefore() => _normalizeReminderDays(
        _box.get(
          SettingsKeys.deadlineReminderDaysBeforeKey,
          defaultValue: SettingsRepository.defaultDeadlineReminderDaysBefore,
        ) as int,
      );

  Future<void> setDeadlineReminderDaysBefore(int days) async => _box.put(
        SettingsKeys.deadlineReminderDaysBeforeKey,
        _normalizeReminderDays(days),
      );

  Future<void> resetNotificationSettingsToDefaults(
      {required bool notificationsEnabled}) async {
    await Future.wait([
      _box.put(SettingsKeys.notificationsEnabledKey, notificationsEnabled),
      _box.put(SettingsKeys.newEventPushEnabledKey, true),
      _box.put(SettingsKeys.subscribedEventsReminderEnabledKey, true),
      _box.put(SettingsKeys.deadlineReminderEnabledKey, true),
      _box.put(SettingsKeys.weeklyPushSummaryEnabledKey, true),
      _box.put(
        SettingsKeys.subscribedEventsReminderDaysBeforeKey,
        SettingsRepository.defaultSubscribedEventsReminderDaysBefore,
      ),
      _box.put(
        SettingsKeys.deadlineReminderDaysBeforeKey,
        SettingsRepository.defaultDeadlineReminderDaysBefore,
      ),
    ]);
  }

  int _normalizeReminderDays(int days) {
    if (days < 1) return 1;
    if (days > 10) return 10;
    return days;
  }
}
