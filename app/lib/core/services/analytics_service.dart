import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/data/settings_repository.dart';
import '../config/app_config.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final service = AnalyticsService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class AnalyticsService {
  AnalyticsService(this._ref);

  final Ref _ref;
  bool _initialized = false;
  String? _distinctId;
  final String _sessionId = 'session-${DateTime.now().microsecondsSinceEpoch}';
  final bool _replayEnabled = true;

  static const String _distinctIdStorageKey = 'analytics.distinct_id';

  static Map<String, Object?> buildPayload({
    required String eventName,
    required String distinctId,
    required String sessionId,
    required bool replayEnabled,
    Map<String, Object?>? properties,
  }) {
    return <String, Object?>{
      'api_key': AppConfig.posthogApiKey,
      'event': eventName,
      'distinct_id': distinctId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'properties': <String, Object?>{
        'app': 'dpsg_news_app',
        'platform': Platform.operatingSystem,
        'app_version': '0.1.0',
        'session_id': sessionId,
        'replay_enabled': replayEnabled,
        ..._sanitizePropertiesStatic(properties ?? const <String, Object?>{}),
      },
    };
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _ensureDistinctId();
    if (!_shouldSend()) {
      return;
    }
    await capture('app_initialized', properties: {
      'platform': Platform.operatingSystem,
      'app': 'dpsg_news_app',
    });
  }

  Future<void> capture(String eventName, {Map<String, Object?>? properties}) async {
    if (!_shouldSend()) {
      return;
    }

    try {
      final payload = buildPayload(
        eventName: eventName,
        distinctId: await _distinctIdOrCreate(),
        sessionId: _sessionId,
        replayEnabled: _replayEnabled,
        properties: properties,
      );

      await http
          .post(
            Uri.parse('${AppConfig.posthogHost}/capture/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Keep analytics resilient and never block the app.
    }
  }

  Future<void> trackScreenView(String screenName, {String? previousScreen, String? source}) {
    return capture(
      'screen_view',
      properties: <String, Object?>{
        'screen': screenName,
        if (previousScreen != null) 'previous_screen': previousScreen,
        if (source != null) 'source': source,
      },
    );
  }

  Future<void> trackFeatureEvent(
    String eventName, {
    required String screen,
    String? action,
    String? target,
    String? source,
    Map<String, Object?>? additionalProperties,
  }) {
    return capture(
      eventName,
      properties: <String, Object?>{
        'screen': screen,
        if (action != null) 'action': action,
        if (target != null) 'target': target,
        if (source != null) 'source': source,
        ...?additionalProperties,
      },
    );
  }

  Future<void> trackSettingsChange(String settingKey, Object? value, {String? group}) {
    return capture(
      'settings_changed',
      properties: <String, Object?>{
        'setting_key': settingKey,
        if (group != null) 'setting_group': group,
        'value': _normalizeValue(value),
      },
    );
  }

  Future<void> trackDvSelectionChanged(List<String> selectedDvs) {
    return capture(
      'dv_selection_changed',
      properties: <String, Object?>{
        'screen': 'settings',
        'setting_key': 'dv_selection',
        'value': selectedDvs,
      },
    );
  }

  Future<void> trackError(String message, {String? screen, String? context}) {
    return capture(
      'error_captured',
      properties: <String, Object?>{
        'message': message,
        if (screen != null) 'screen': screen,
        if (context != null) 'context': context,
      },
    );
  }

  Future<void> trackUiClick(String element, {String? screen, String? action, String? target}) {
    return capture(
      'ui_click',
      properties: <String, Object?>{
        'element': element,
        if (screen != null) 'screen': screen,
        if (action != null) 'action': action,
        if (target != null) 'target': target,
      },
    );
  }

  Future<void> dispose() async {}

  bool _shouldSend() {
    if (!AppConfig.hasPosthogConfig) {
      return false;
    }

    try {
      return _ref.read(settingsRepositoryProvider).getAnalyticsTracking();
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureDistinctId() async {
    final prefs = await SharedPreferences.getInstance();
    _distinctId = prefs.getString(_distinctIdStorageKey);
    if (_distinctId == null || _distinctId!.isEmpty) {
      _distinctId = 'anon-${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString(_distinctIdStorageKey, _distinctId!);
    }
  }

  Future<String> _distinctIdOrCreate() async {
    if (_distinctId == null || _distinctId!.isEmpty) {
      await _ensureDistinctId();
    }
    return _distinctId ?? 'anonymous';
  }

  static Map<String, Object?> _sanitizePropertiesStatic(Map<String, Object?> properties) {
    final sanitized = <String, Object?>{};
    for (final entry in properties.entries) {
      final key = entry.key;
      if (key.contains('token') || key.contains('secret') || key.contains('auth')) {
        sanitized[key] = '<redacted>';
      } else {
        sanitized[key] = _normalizeValueStatic(entry.value);
      }
    }
    return sanitized;
  }

  Object? _normalizeValue(Object? value) {
    return _normalizeValueStatic(value);
  }

  static Object? _normalizeValueStatic(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Iterable) {
      return value.map(_normalizeValueStatic).toList(growable: false);
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), _normalizeValueStatic(val)));
    }
    return value.toString();
  }
}
