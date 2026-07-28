import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/logging_service.dart';

void main() {
  late ProviderContainer container;
  late LoggingService logger;

  setUp(() async {
    container = ProviderContainer();
    logger = container.read(loggingServiceProvider);
    // getApplicationSupportDirectory() ist im Testlauf nicht verfuegbar und
    // faellt intern auf ein fixes Verzeichnis unter systemTemp zurueck --
    // das persistiert ueber Testfaelle/-laeufe desselben Tages hinweg.
    // Erst leeren, damit jeder Test mit einem sauberen Log-Stand startet.
    await logger.clearAllLogs(source: LogSource.app);
    await logger.clearAllLogs(source: LogSource.request);
  });

  tearDown(() {
    container.dispose();
  });

  group('currentRouteName', () {
    test('defaults to "root" before any route has been set', () {
      expect(logger.currentRouteName, 'root');
    });

    test('updates when a non-empty route name is set', () {
      logger.setCurrentRouteName('EventsScreen');
      expect(logger.currentRouteName, 'EventsScreen');
    });

    test('ignores null or empty route names', () {
      logger.setCurrentRouteName('EventsScreen');
      logger.setCurrentRouteName(null);
      expect(logger.currentRouteName, 'EventsScreen');
      logger.setCurrentRouteName('');
      expect(logger.currentRouteName, 'EventsScreen');
    });
  });

  group('writing and reading logs', () {
    test('logInfo appends a formatted line to the in-memory app logs',
        () async {
      await logger.logInfo('sync', 'started syncing events');

      final logs = logger.getAppLogs();
      expect(logs, isNotEmpty);
      expect(logs.first, contains('[info] [sync] started syncing events'));
    });

    test('logWarn is tagged with the warn level', () async {
      await logger.logWarn('sync', 'retrying after failure');

      expect(logger.getAppLogs().first, contains('[warn] [sync]'));
    });

    test('getAppLogs returns entries newest-first', () async {
      await logger.logInfo('sync', 'first');
      await logger.logInfo('sync', 'second');

      final logs = logger.getAppLogs();
      expect(logs[0], contains('second'));
      expect(logs[1], contains('first'));
    });

    test('logRequest combines request and response into a single request-log line',
        () async {
      logger.logRequest('GET /api/events', response: '200');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final logs = logger.getRequestLogs();
      expect(logs.first, contains('GET /api/events -> 200'));
    });

    test('written app logs are persisted to a file that can be read back',
        () async {
      await logger.logInfo('sync', 'persisted line');

      final content = await logger.readLogs(source: LogSource.app);
      expect(content, contains('persisted line'));
    });

    test('clearAllLogs empties both the in-memory list and the log file',
        () async {
      await logger.logInfo('sync', 'to be cleared');
      expect(logger.getAppLogs(), isNotEmpty);

      await logger.clearAllLogs(source: LogSource.app);

      expect(logger.getAppLogs(), isEmpty);
      expect(await logger.readLogs(source: LogSource.app), isEmpty);
    });

    test('clearAllAppLogs is a shorthand for clearAllLogs(source: app)',
        () async {
      await logger.logInfo('sync', 'to be cleared via shorthand');
      await logger.clearAllAppLogs();

      expect(logger.getAppLogs(), isEmpty);
    });
  });

  group('logHttpRequestResult', () {
    test('redacts token/secret/auth query parameters from the logged URL',
        () async {
      await logger.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: Uri.parse(
            'https://api.example.org/events?token=super-secret&layerId=3'),
        durationMs: 12,
        statusCode: 200,
      );

      final line = logger.getRequestLogs().first;
      expect(line, contains('token=%3Credacted%3E'));
      expect(line, contains('layerId=3'));
      expect(line, isNot(contains('super-secret')));
    });

    test('logs at error level and includes the response body for a 4xx status',
        () async {
      await logger.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: Uri.parse('https://api.example.org/events'),
        durationMs: 5,
        statusCode: 404,
        responseBody: 'Not found',
      );

      final line = logger.getRequestLogs().first;
      expect(line, contains('[error]'));
      expect(line, contains('status=404'));
      expect(line, contains('body=Not found'));
    });

    test('logs at info level and omits the body for a successful response',
        () async {
      await logger.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: Uri.parse('https://api.example.org/events'),
        durationMs: 5,
        statusCode: 200,
        responseBody: 'should not appear',
      );

      final line = logger.getRequestLogs().first;
      expect(line, contains('[info]'));
      expect(line, isNot(contains('should not appear')));
    });

    test('truncates an overly long response body', () async {
      final longBody = 'x' * 2000;
      await logger.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: Uri.parse('https://api.example.org/events'),
        durationMs: 5,
        statusCode: 500,
        responseBody: longBody,
      );

      final line = logger.getRequestLogs().first;
      expect(line, contains('...'));
      expect(line.length, lessThan(longBody.length + 200));
    });

    test('includes the error type and message when a request error occurred',
        () async {
      await logger.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: Uri.parse('https://api.example.org/events'),
        durationMs: 5,
        error: const FormatException('bad json'),
      );

      final line = logger.getRequestLogs().first;
      expect(line, contains('[error]'));
      expect(line, contains('error_type=FormatException'));
      expect(line, contains('bad json'));
    });
  });

  group('AppNavigationLoggingObserver', () {
    // Bewusst als reiner Unit-Test ohne WidgetTester/Navigator: didPush/didPop
    // benoetigen keinen gemounteten Navigator (NavigatorObserver's Basis-
    // implementierung ist ein No-op), und Route-Objekte lassen sich direkt
    // konstruieren. Das haelt den Test schnell und robust gegenueber
    // Timing-Problemen bei echten Seitenuebergaengen/Animationen.
    test('didPush updates the current route name and logs route_open',
        () async {
      final observer = AppNavigationLoggingObserver(logger: logger);
      final rootRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'Root'),
        builder: (_) => const SizedBox(),
      );
      final detailRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'EventDetail'),
        builder: (_) => const SizedBox(),
      );

      observer.didPush(detailRoute, rootRoute);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(logger.currentRouteName, 'EventDetail');
      final line = logger.getAppLogs().first;
      expect(line, contains('route_open'));
      expect(line, contains('route=EventDetail'));
      expect(line, contains('from=Root'));
    });

    test('didPop restores the previous route name and logs route_back',
        () async {
      final observer = AppNavigationLoggingObserver(logger: logger);
      final rootRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'Root'),
        builder: (_) => const SizedBox(),
      );
      final detailRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'EventDetail'),
        builder: (_) => const SizedBox(),
      );

      observer.didPop(detailRoute, rootRoute);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(logger.currentRouteName, 'Root');
      final line = logger.getAppLogs().first;
      expect(line, contains('route_back'));
      expect(line, contains('from=EventDetail'));
      expect(line, contains('to=Root'));
    });

    test('falls back to the route\'s runtime type when no name is configured',
        () async {
      final observer = AppNavigationLoggingObserver(logger: logger);
      final unnamedRoute = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
      );

      observer.didPush(unnamedRoute, null);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(logger.currentRouteName, contains('MaterialPageRoute'));
    });
  });
}
