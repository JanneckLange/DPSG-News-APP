part of '../settings_repository.dart';

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

final eventViewedAtProvider =
    StateNotifierProvider<EventViewedAtNotifier, Map<String, DateTime>>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return EventViewedAtNotifier(repository);
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

final hasSeenWelcomeProvider =
    StateNotifierProvider<HasSeenWelcomeNotifier, bool>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return HasSeenWelcomeNotifier(repository);
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

class EventViewedAtNotifier extends StateNotifier<Map<String, DateTime>> {
  EventViewedAtNotifier(this._repository)
      : super(_repository.getEventViewedAt());

  final SettingsRepository _repository;

  Future<void> markViewed(String eventId) async {
    if (eventId.isEmpty) return;
    final updated = {...state, eventId: DateTime.now()};
    await _repository.setEventViewedAt(updated);
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

class HasSeenWelcomeNotifier extends StateNotifier<bool> {
  HasSeenWelcomeNotifier(this._repository)
      : super(_repository.getHasSeenWelcome());

  final SettingsRepository _repository;

  Future<void> setHasSeenWelcome(bool value) async {
    await _repository.setHasSeenWelcome(value);
    state = value;
  }
}
