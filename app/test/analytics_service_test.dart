import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dpsg_news_app/core/services/analytics_service.dart';

void main() {
  group('AnalyticsService payload building', () {
    test('includes session and replay context in the payload', () {
      final payload = AnalyticsService.buildPayload(
        eventName: 'dv_selection_changed',
        distinctId: 'user-123',
        sessionId: 'session-456',
        replayEnabled: true,
        properties: {
          'screen': 'settings',
          'setting_key': 'dv_selection',
        },
      );

      final properties = payload['properties'] as Map<String, Object?>;
      expect(properties['screen'], 'settings');
      expect(properties['setting_key'], 'dv_selection');
      expect(properties['session_id'], 'session-456');
      expect(properties['replay_enabled'], true);
      expect(properties['app'], 'dpsg_news_app');
    });

    test('redacts properties whose key looks like a credential', () {
      final payload = AnalyticsService.buildPayload(
        eventName: 'test_event',
        distinctId: 'user-123',
        sessionId: 'session-456',
        replayEnabled: true,
        properties: {
          'access_token': 'super-secret-value',
          'client_secret': 'another-secret',
          'auth_header': 'Bearer xyz',
          'username': 'max',
        },
      );

      final properties = payload['properties'] as Map<String, Object?>;
      expect(properties['access_token'], '<redacted>');
      expect(properties['client_secret'], '<redacted>');
      expect(properties['auth_header'], '<redacted>');
      expect(properties['username'], 'max');
    });

    test('normalizes DateTime, Iterable and Map property values', () {
      final payload = AnalyticsService.buildPayload(
        eventName: 'test_event',
        distinctId: 'user-123',
        sessionId: 'session-456',
        replayEnabled: true,
        properties: {
          'created_at': DateTime.utc(2026, 1, 1),
          'selected_ids': [1, 2, 3],
          'nested': {'key': 'value'},
          'count': 42,
          'enabled': true,
        },
      );

      final properties = payload['properties'] as Map<String, Object?>;
      expect(properties['created_at'], '2026-01-01T00:00:00.000Z');
      expect(properties['selected_ids'], [1, 2, 3]);
      expect(properties['nested'], {'key': 'value'});
      expect(properties['count'], 42);
      expect(properties['enabled'], true);
    });

    test('falls back to toString() for values of an unsupported type', () {
      final payload = AnalyticsService.buildPayload(
        eventName: 'test_event',
        distinctId: 'user-123',
        sessionId: 'session-456',
        replayEnabled: true,
        properties: {'theme_mode': ThemeModeStub.dark},
      );

      final properties = payload['properties'] as Map<String, Object?>;
      expect(properties['theme_mode'], 'ThemeModeStub.dark');
    });
  });

  group('AnalyticsService instance behavior without PostHog configuration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
        'capture() (via the tracking helpers) completes immediately without attempting a network call',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(analyticsServiceProvider);

      // Kein POSTHOG_API_KEY/POSTHOG_PROJECT_ID im Testlauf konfiguriert ->
      // AppConfig.hasPosthogConfig ist false -> _shouldSend() liefert immer
      // false -> capture() kehrt sofort zurueck, ohne http.post() zu rufen.
      // Ein kurzes Timeout genuegt, um das abzusichern: ein echter (in
      // Tests unerreichbarer) Netzwerkversuch wuerde es reissen.
      await service
          .trackScreenView('settings')
          .timeout(const Duration(milliseconds: 200));
      await service
          .trackFeatureEvent('author_login_started', screen: 'author_login')
          .timeout(const Duration(milliseconds: 200));
      await service
          .trackSettingsChange('theme', 'dark')
          .timeout(const Duration(milliseconds: 200));
      await service
          .trackDvSelectionChanged(['Köln'])
          .timeout(const Duration(milliseconds: 200));
      await service
          .trackError('boom', screen: 'settings')
          .timeout(const Duration(milliseconds: 200));
      await service
          .trackUiClick('save_button')
          .timeout(const Duration(milliseconds: 200));
    });

    test('initialize() is idempotent and completes without a PostHog config',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(analyticsServiceProvider);

      await service.initialize().timeout(const Duration(milliseconds: 500));
      await service.initialize().timeout(const Duration(milliseconds: 500));
    });

    test('dispose() completes without throwing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(analyticsServiceProvider);

      await service.dispose();
    });
  });
}

enum ThemeModeStub { light, dark }
