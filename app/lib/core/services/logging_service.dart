import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wiredash/wiredash.dart';

import '../../features/settings/data/settings_repository.dart';
import 'app_navigation_service.dart';
import 'logging_env.dart';

enum LogSource { app, request }

enum LogEmailSendResult { sent, noFiles, unavailable }

final loggingServiceProvider = Provider<LoggingService>((ref) {
  final service = LoggingService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class LoggingService {
  static const String allLogsSelectionId = '__all__';

  LoggingService(this._ref);

  final Ref _ref;
  final List<String> _recentAppLogs = <String>[];
  final List<String> _recentRequestLogs = <String>[];

  DateTime? _lastCleanupAt;
  Future<void>? _cleanupFuture;
  String? _currentRouteName;

  void dispose() {}

  String get currentRouteName => _currentRouteName ?? 'root';

  void setCurrentRouteName(String? routeName) {
    if (routeName == null || routeName.isEmpty) {
      return;
    }
    _currentRouteName = routeName;
  }

  void logEvent(String event, {Map<String, Object?>? properties}) {
    unawaited(trackAndLog('ui', event, properties ?? const <String, Object?>{}));
  }

  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    unawaited(logServiceError('app', message, error: error, stackTrace: stackTrace));
  }

  void logRequest(String request, {String? response}) {
    final payload = response == null ? request : '$request -> $response';
    unawaited(_writeLogLine(LogSource.request, 'info', 'http', payload));
  }

  List<String> getAppLogs() => List<String>.from(_recentAppLogs.reversed);

  List<String> getRequestLogs() => List<String>.from(_recentRequestLogs.reversed);

  Future<void> logInfo(String service, String message) {
    return _writeLogLine(LogSource.app, 'info', service, message);
  }

  Future<void> logWarn(String service, String message) {
    return _writeLogLine(LogSource.app, 'warn', service, message);
  }

  Future<void> logServiceError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write(' error=${error.runtimeType}: $error');
    }
    if (stackTrace != null) {
      buffer.write(' stack=$stackTrace');
    }
    return _writeLogLine(LogSource.app, 'error', service, buffer.toString());
  }

  Future<void> logNavigationAction(
    String action, {
    String? route,
    String? fromRoute,
    String? toRoute,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    final details = <String, Object?>{
      if (route != null) 'route': route,
      if (fromRoute != null) 'from': fromRoute,
      if (toRoute != null) 'to': toRoute,
      ...properties,
    };
    return logInfo('nav', _composeMessage(action, details));
  }

  Future<void> logTap({required double x, required double y}) {
    return logInfo(
      'ui',
      _composeMessage('tap', <String, Object?>{
        'route': currentRouteName,
        'x': x.toStringAsFixed(1),
        'y': y.toStringAsFixed(1),
      }),
    );
  }

  Future<void> trackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {
    await logInfo(service, _composeMessage(name, properties));
    await _trackEvent(name, properties);
  }

  Future<void> logHttpRequestStart({
    required String source,
    required String method,
    required Uri uri,
  }) {
    final safeUri = _sanitizeUri(uri);
    return _writeLogLine(
      LogSource.request,
      'info',
      'http',
      'request_start source=$source method=${method.toUpperCase()} url=$safeUri',
    );
  }

  Future<void> logHttpRequestResult({
    required String source,
    required String method,
    required Uri uri,
    required int durationMs,
    int? statusCode,
    Object? error,
    String? responseBody,
  }) {
    final safeUri = _sanitizeUri(uri);
    final isError = error != null || (statusCode != null && statusCode >= 400);
    final buffer = StringBuffer(
      'request_result source=$source method=${method.toUpperCase()} url=$safeUri duration_ms=$durationMs',
    );
    if (statusCode != null) {
      buffer.write(' status=$statusCode');
    }
    if (error != null) {
      buffer.write(' error_type=${error.runtimeType} error=$error');
    }
    if (isError && responseBody != null && responseBody.isNotEmpty) {
      buffer.write(' body=${_normalizeBody(responseBody)}');
    }

    return _writeLogLine(
      LogSource.request,
      isError ? 'error' : 'info',
      'http',
      buffer.toString(),
    );
  }

  Future<List<String>> listLogFileNames({required LogSource source}) async {
    final files = await _listLogFiles(source);
    return files.map(_fileBaseName).toList(growable: false);
  }

  Future<List<File>> resolveLogFiles({required LogSource source, String? selectionId}) async {
    final files = await _listLogFiles(source);
    if (selectionId == null || selectionId == allLogsSelectionId) {
      return files;
    }

    return files.where((file) => _fileBaseName(file) == selectionId).toList(growable: false);
  }

  Future<LogEmailSendResult> sendLogsByEmail({required LogSource source, String? selectionId}) async {
    final files = await resolveLogFiles(source: source, selectionId: selectionId);
    final existingFiles = <File>[];
    for (final file in files) {
      if (await file.exists()) {
        existingFiles.add(file);
      }
    }

    if (existingFiles.isEmpty) {
      return LogEmailSendResult.noFiles;
    }

    try {
      await FlutterEmailSender.send(
        Email(
          body: 'Anbei die angeforderten Logs.',
          attachmentPaths: existingFiles.map((file) => file.path).toList(growable: false),
          subject: 'DPSG News Logs',
          recipients: const ['dev@jannecklange.de'],
        ),
      );
      return LogEmailSendResult.sent;
    } catch (error, stackTrace) {
      await logServiceError('debug_tools', 'send_logs_email_failed', error: error, stackTrace: stackTrace);
      return LogEmailSendResult.unavailable;
    }
  }

  Future<String> readLogs({required LogSource source, String? selectionId}) async {
    final files = await resolveLogFiles(source: source, selectionId: selectionId);
    if (files.isEmpty) {
      return '';
    }

    final ordered = (selectionId == null || selectionId == allLogsSelectionId)
        ? files.reversed.toList(growable: false)
        : files;
    if (ordered.length == 1) {
      return ordered.single.readAsString();
    }

    final buffer = StringBuffer();
    for (final file in ordered) {
      final name = _fileBaseName(file);
      final content = await file.readAsString();
      buffer.writeln('===== $name =====');
      if (content.isNotEmpty) {
        buffer.write(content);
        if (!content.endsWith('\n')) {
          buffer.writeln();
        }
      }
      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  Future<void> clearAllLogs({required LogSource source}) async {
    final files = await _listLogFiles(source);
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (source == LogSource.app) {
      _recentAppLogs.clear();
    } else {
      _recentRequestLogs.clear();
    }
  }

  Future<void> clearAllAppLogs() => clearAllLogs(source: LogSource.app);

  Future<void> _writeLogLine(LogSource source, String level, String service, String message) async {
    await _maybeCleanupLogs(source);
    final ts = _timestamp(DateTime.now());
    final line = '[$ts] [$level] [$service] $message';
    developer.log(line, name: 'dpsg_logs');

    _addRecent(source, line);

    final file = await _logFile(source);
    await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  void _addRecent(LogSource source, String line) {
    final target = source == LogSource.app ? _recentAppLogs : _recentRequestLogs;
    target.add(line);
    if (target.length > 500) {
      target.removeRange(0, target.length - 500);
    }
  }

  Future<Directory> _logsDirectory(LogSource source) async {
    Directory baseDir;
    try {
      baseDir = await getApplicationSupportDirectory();
    } catch (_) {
      baseDir = Directory('${Directory.systemTemp.path}/dpsg_news_app');
    }

    final subdir = source == LogSource.app ? 'logs' : 'request_logs';
    final logsDir = Directory('${baseDir.path}/$subdir');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  Future<File> _logFile(LogSource source) async {
    final dir = await _logsDirectory(source);
    final prefix = source == LogSource.app ? 'app' : 'request';
    final day = _dateLabel(DateTime.now());
    final file = File('${dir.path}/$prefix-$day.log');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<List<File>> _listLogFiles(LogSource source) async {
    final dir = await _logsDirectory(source);
    if (!await dir.exists()) {
      return const <File>[];
    }

    final entities = await dir.list().toList();
    final files = entities.whereType<File>().where((f) => f.path.endsWith('.log')).toList(growable: false)
      ..sort((left, right) => _fileBaseName(left).compareTo(_fileBaseName(right)));
    return files;
  }

  Future<void> _trackEvent(String name, Map<String, Object?> properties) async {
    if (!_isAnalyticsTrackingEnabled()) {
      return;
    }
    await _trackWiredashEvent(name, properties);
  }

  bool _isAnalyticsTrackingEnabled() {
    try {
      return _ref.read(settingsRepositoryProvider).getAnalyticsTracking();
    } catch (_) {
      return false;
    }
  }

  Future<void> _trackWiredashEvent(String name, Map<String, Object?> properties) async {
    try {
      final navigatorKey = _ref.read(appNavigatorKeyProvider);
      final context = navigatorKey.currentContext;

      if (context == null) return;
      await Wiredash.of(context).trackEvent(name, data: properties);
    } catch (_) {
      // Keep logging resilient when Wiredash is unavailable.
    }
  }

  String _composeMessage(String action, Map<String, Object?> properties) {
    final details = _formatProperties(properties);
    if (details.isEmpty) {
      return action;
    }
    return '$action $details';
  }

  String _formatProperties(Map<String, Object?> properties) {
    if (properties.isEmpty) {
      return '';
    }

    final entries = properties.entries.toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));
    return entries.map((entry) => '${entry.key}=${_sanitizeValue(entry.value)}').join(' ');
  }

  String _sanitizeValue(Object? value) {
    if (value == null) {
      return 'null';
    }
    return value.toString().replaceAll('\n', '\\n');
  }

  Uri _sanitizeUri(Uri uri) {
    if (uri.queryParameters.isEmpty) {
      return uri;
    }

    final sanitized = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      final lower = entry.key.toLowerCase();
      if (lower.contains('token') || lower.contains('secret') || lower.contains('auth')) {
        sanitized[entry.key] = '<redacted>';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return uri.replace(queryParameters: sanitized);
  }

  String _normalizeBody(String body) {
    final compact = body.replaceAll('\n', '\\n');
    if (compact.length <= 1200) {
      return compact;
    }
    return '${compact.substring(0, 1197)}...';
  }

  Future<void> _maybeCleanupLogs(LogSource source) async {
    final now = DateTime.now();
    if (_lastCleanupAt != null && now.difference(_lastCleanupAt!) < const Duration(minutes: 5)) {
      return;
    }

    final existing = _cleanupFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final cleanup = _cleanupLogs(source);
    _cleanupFuture = cleanup;
    try {
      await cleanup;
      _lastCleanupAt = now;
    } finally {
      _cleanupFuture = null;
    }
  }

  Future<void> _cleanupLogs(LogSource source) async {
    final files = await _listLogFiles(source);
    if (files.isEmpty) {
      return;
    }

    final prefix = source == LogSource.app ? 'app' : 'request';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final earliestKeptDay = today.subtract(Duration(days: LoggingEnv.maxDays - 1));

    for (final file in files) {
      final parsedDay = _parseLogDate(file, prefix);
      if (parsedDay == null) {
        continue;
      }
      final isToday = _isSameDay(parsedDay, today);
      if (!isToday && parsedDay.isBefore(earliestKeptDay)) {
        await file.delete();
      }
    }

    final retainedFiles = await _listLogFiles(source);
    var totalBytes = 0;
    final deletable = <File>[];
    for (final file in retainedFiles) {
      if (!await file.exists()) {
        continue;
      }
      final stat = await file.stat();
      totalBytes += stat.size;
      final day = _parseLogDate(file, prefix);
      if (day != null && !_isSameDay(day, today)) {
        deletable.add(file);
      }
    }

    if (totalBytes <= LoggingEnv.maxSizeBytes) {
      return;
    }

    deletable.sort((left, right) {
      final leftDay = _parseLogDate(left, prefix) ?? today;
      final rightDay = _parseLogDate(right, prefix) ?? today;
      return leftDay.compareTo(rightDay);
    });

    for (final file in deletable) {
      if (totalBytes <= LoggingEnv.maxSizeBytes) {
        break;
      }
      final stat = await file.stat();
      await file.delete();
      totalBytes -= stat.size;
    }
  }

  DateTime? _parseLogDate(File file, String prefix) {
    final name = _fileBaseName(file);
    final regex = RegExp('^${RegExp.escape(prefix)}-(\\d{4}-\\d{2}-\\d{2})\\.log');
    final match = regex.firstMatch(name);
    if (match == null) {
      return null;
    }
    return DateTime.tryParse(match.group(1)!);
  }

  String _fileBaseName(File file) {
    final separator = Platform.pathSeparator;
    final parts = file.path.split(separator);
    return parts.isEmpty ? file.path : parts.last;
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  String _dateLabel(DateTime dateTime) {
    final y = dateTime.year.toString().padLeft(4, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _timestamp(DateTime dateTime) {
    final y = dateTime.year.toString().padLeft(4, '0');
    final mo = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    final h = dateTime.hour.toString().padLeft(2, '0');
    final mi = dateTime.minute.toString().padLeft(2, '0');
    final s = dateTime.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }
}

class AppNavigationLoggingObserver extends NavigatorObserver {
  AppNavigationLoggingObserver({required LoggingService logger}) : _logger = logger;

  final LoggingService _logger;

  String _resolveRouteName(Route<dynamic> route) {
    final configuredName = route.settings.name;
    if (configuredName != null && configuredName.isNotEmpty) {
      return configuredName;
    }
    return route.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final routeName = _resolveRouteName(route);
    _logger.setCurrentRouteName(routeName);
    unawaited(
      _logger.logNavigationAction(
        'route_open',
        route: routeName,
        fromRoute: previousRoute == null ? null : _resolveRouteName(previousRoute),
      ),
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final fromRoute = _resolveRouteName(route);
    final toRoute = previousRoute == null ? null : _resolveRouteName(previousRoute);
    _logger.setCurrentRouteName(toRoute);
    unawaited(
      _logger.logNavigationAction(
        'route_back',
        fromRoute: fromRoute,
        toRoute: toRoute,
      ),
    );
  }
}
