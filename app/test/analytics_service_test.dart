import 'package:flutter_test/flutter_test.dart';
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
  });
}
