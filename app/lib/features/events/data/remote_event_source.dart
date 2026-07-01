import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/services/logging_service.dart';

class RemoteEventSource {
  RemoteEventSource({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
    this.logger,
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;
  final Duration timeout;
  final LoggingService? logger;

  Future<List<Map<String, dynamic>>> fetchEvents() async {
    final uri = baseUrl.replace(path: '/api/events');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.get(uri).timeout(timeout);
      stopwatch.stop();

      await logger?.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        error: response.statusCode == 200 ? null : StateError('http_status_${response.statusCode}'),
        responseBody: response.statusCode == 200 ? null : response.body,
      );

      if (response.statusCode != 200) {
        throw RemoteEventSourceException(
          'Failed to fetch events: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(json['events'] as List<dynamic>);
    } on TimeoutException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Timed out while fetching events',
        exception: error,
        stackTrace: stackTrace,
      );
    } on SocketException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Unable to reach the event server',
        exception: error,
        stackTrace: stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Received invalid response from server',
        exception: error,
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.fetchEvents',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Network error while fetching events',
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ApiHealthStatus> checkHealth() async {
    final uri = baseUrl.replace(path: '/health');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.get(uri).timeout(timeout);
      stopwatch.stop();

      await logger?.logHttpRequestResult(
        source: 'events.checkHealth',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        error: response.statusCode == 200 ? null : StateError('http_status_${response.statusCode}'),
        responseBody: response.statusCode == 200 ? null : response.body,
      );

      if (response.statusCode == 200) {
        return ApiHealthStatus(true, 'Server erreichbar');
      }
      return ApiHealthStatus(false, 'Server antwortet mit ${response.statusCode}');
    } on TimeoutException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.checkHealth',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Health check timed out',
        exception: error,
        stackTrace: stackTrace,
      );
    } on SocketException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.checkHealth',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Unable to reach health endpoint',
        exception: error,
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.checkHealth',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Network error during health check',
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, dynamic>> fetchDvTree() async {
    final uri = baseUrl.replace(path: '/api/dvs');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.get(uri).timeout(timeout);
      stopwatch.stop();

      await logger?.logHttpRequestResult(
        source: 'events.fetchDvTree',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        error: response.statusCode == 200 ? null : StateError('http_status_${response.statusCode}'),
        responseBody: response.statusCode == 200 ? null : response.body,
      );

      if (response.statusCode != 200) {
        throw RemoteEventSourceException(
          'Failed to fetch DV tree: ${response.statusCode}',
        );
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.fetchDvTree',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Timed out while fetching DV tree',
        exception: error,
        stackTrace: stackTrace,
      );
    } on SocketException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.fetchDvTree',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Unable to reach the event server',
        exception: error,
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.fetchDvTree',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Network error while fetching DV tree',
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> event) async {
    final uri = baseUrl.replace(path: '/api/events');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client
          .post(
            uri,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode(event),
          )
          .timeout(timeout);
      stopwatch.stop();

      await logger?.logHttpRequestResult(
        source: 'events.createEvent',
        method: 'post',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        error: response.statusCode == 201 ? null : StateError('http_status_${response.statusCode}'),
        responseBody: response.statusCode == 201 ? null : response.body,
      );

      if (response.statusCode != 201) {
        throw RemoteEventSourceException(
          'Failed to create event: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['event'] as Map<String, dynamic>;
    } on TimeoutException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.createEvent',
        method: 'post',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Timed out while creating event',
        exception: error,
        stackTrace: stackTrace,
      );
    } on SocketException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.createEvent',
        method: 'post',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Unable to reach the event server',
        exception: error,
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.createEvent',
        method: 'post',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Network error while creating event',
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class ApiHealthStatus {
  ApiHealthStatus(this.healthy, this.message);

  final bool healthy;
  final String message;
}

class RemoteEventSourceException implements Exception {
  RemoteEventSourceException(
    this.message, {
    this.exception,
    this.stackTrace,
  });

  final String message;
  final Object? exception;
  final StackTrace? stackTrace;

  @override
  String toString() => 'RemoteEventSourceException: $message';
}
