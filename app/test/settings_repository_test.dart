import 'dart:io';

import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SettingsRepository repository;

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.initialize(path: tempDir.path);
  });

  setUp(() {
    repository = SettingsRepository(HiveService.getSettingsBox());
  });

  tearDown(() async {
    await HiveService.getSettingsBox().clear();
    await HiveService.getEventsBox().clear();
  });

  test('persists app theme mode', () async {
    expect(repository.getAppThemeMode(), 'system');

    await repository.setAppThemeMode('dark');

    expect(repository.getAppThemeMode(), 'dark');
  });

  test('persists analytics tracking toggle', () async {
    expect(repository.getAnalyticsTracking(), isTrue);

    await repository.setAnalyticsTracking(false);

    expect(repository.getAnalyticsTracking(), isFalse);
  });

  test('persists app language', () async {
    expect(repository.getAppLanguage(), 'de');

    await repository.setAppLanguage('de');

    expect(repository.getAppLanguage(), 'de');
  });

  test('persists notifications enabled toggle', () async {
    expect(repository.getNotificationsEnabled(), isTrue);

    await repository.setNotificationsEnabled(false);

    expect(repository.getNotificationsEnabled(), isFalse);
  });

  test('persists new event push toggle', () async {
    expect(repository.getNewEventPushEnabled(), isTrue);

    await repository.setNewEventPushEnabled(false);

    expect(repository.getNewEventPushEnabled(), isFalse);
  });

  test('persists subscribed events reminder toggle', () async {
    expect(repository.getSubscribedEventsReminderEnabled(), isTrue);

    await repository.setSubscribedEventsReminderEnabled(false);

    expect(repository.getSubscribedEventsReminderEnabled(), isFalse);
  });

  test('persists deadline reminder toggle', () async {
    expect(repository.getDeadlineReminderEnabled(), isTrue);

    await repository.setDeadlineReminderEnabled(false);

    expect(repository.getDeadlineReminderEnabled(), isFalse);
  });

  test('persists weekly push summary toggle', () async {
    expect(repository.getWeeklyPushSummaryEnabled(), isTrue);

    await repository.setWeeklyPushSummaryEnabled(false);

    expect(repository.getWeeklyPushSummaryEnabled(), isFalse);
  });

  test('uses reminder day defaults', () {
    expect(repository.getSubscribedEventsReminderDaysBefore(),
        SettingsRepository.defaultSubscribedEventsReminderDaysBefore);
    expect(repository.getDeadlineReminderDaysBefore(),
        SettingsRepository.defaultDeadlineReminderDaysBefore);
  });

  test('persists reminder day values with range normalization', () async {
    await repository.setSubscribedEventsReminderDaysBefore(0);
    await repository.setDeadlineReminderDaysBefore(11);

    expect(repository.getSubscribedEventsReminderDaysBefore(), 1);
    expect(repository.getDeadlineReminderDaysBefore(), 10);
  });

  test('resets notification settings to defaults when global toggle changes', () async {
    await repository.setNotificationsEnabled(false);
    await repository.setNewEventPushEnabled(false);
    await repository.setSubscribedEventsReminderEnabled(false);
    await repository.setDeadlineReminderEnabled(false);
    await repository.setWeeklyPushSummaryEnabled(false);
    await repository.setSubscribedEventsReminderDaysBefore(8);
    await repository.setDeadlineReminderDaysBefore(9);

    await repository.resetNotificationSettingsToDefaults(notificationsEnabled: true);

    expect(repository.getNotificationsEnabled(), isTrue);
    expect(repository.getNewEventPushEnabled(), isTrue);
    expect(repository.getSubscribedEventsReminderEnabled(), isTrue);
    expect(repository.getDeadlineReminderEnabled(), isTrue);
    expect(repository.getWeeklyPushSummaryEnabled(), isTrue);
    expect(repository.getSubscribedEventsReminderDaysBefore(),
        SettingsRepository.defaultSubscribedEventsReminderDaysBefore);
    expect(repository.getDeadlineReminderDaysBefore(),
        SettingsRepository.defaultDeadlineReminderDaysBefore);
  });
}
