import 'package:shared_preferences/shared_preferences.dart';

import 'logging_service.dart';

typedef NowProvider = DateTime Function();

class UsageTrackingService {
  UsageTrackingService({required this.logger, NowProvider? nowProvider})
    : now = nowProvider ?? DateTime.now;

  final LoggingService logger;
  final NowProvider now;
  Duration resumeThreshold = const Duration(minutes: 1);

  DateTime? _start;
  DateTime? _pausedAt;

  void startSession() {
    _start = now();
    _pausedAt = null;
  }

  Future<void> endSession() async {
    final startedAt = _start;
    if (startedAt == null) {
      return;
    }
    final end = now();
    final duration = end.difference(startedAt);
    await logger.logInfo('usage', 'session_duration seconds=${duration.inSeconds}');
    _start = null;
    _pausedAt = null;
  }

  Future<void> flushPendingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final startIso = prefs.getString('usage.pending_start_iso');
    final pausedIso = prefs.getString('usage.pending_paused_iso');
    if (startIso == null || pausedIso == null) {
      return;
    }

    final start = DateTime.tryParse(startIso);
    final paused = DateTime.tryParse(pausedIso);
    if (start == null || paused == null) {
      await prefs.remove('usage.pending_start_iso');
      await prefs.remove('usage.pending_paused_iso');
      return;
    }

    final delta = now().difference(paused);
    if (delta >= resumeThreshold) {
      final seconds = paused.difference(start).inSeconds;
      await logger.logInfo('usage', 'session_duration seconds=$seconds');
    }

    await prefs.remove('usage.pending_start_iso');
    await prefs.remove('usage.pending_paused_iso');
  }

  Future<void> pause() async {
    _pausedAt = now();
    await _persistPauseSnapshot();
  }

  Future<void> resume() async {
    final pausedAt = _pausedAt;
    if (pausedAt == null) {
      await flushPendingSession();
      return;
    }

    final delta = now().difference(pausedAt);
    if (delta > resumeThreshold) {
      await endSession();
      startSession();
    } else {
      _pausedAt = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('usage.pending_start_iso');
      await prefs.remove('usage.pending_paused_iso');
    }
  }

  Future<void> _persistPauseSnapshot() async {
    if (_start == null || _pausedAt == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usage.pending_start_iso', _start!.toIso8601String());
    await prefs.setString('usage.pending_paused_iso', _pausedAt!.toIso8601String());
  }
}
