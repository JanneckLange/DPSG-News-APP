part of '../remote_event_source.dart';

class _RemoteEventSourceBase {
  _RemoteEventSourceBase({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
    this.logger,
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;
  final Duration timeout;
  final LoggingService? logger;

  String? _parseServerError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Response body war kein JSON oder hatte kein error-Feld - ignorieren.
    }
    return null;
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
        error: response.statusCode == 200
            ? null
            : StateError('http_status_${response.statusCode}'),
        responseBody: response.statusCode == 200 ? null : response.body,
      );

      if (response.statusCode == 200) {
        return ApiHealthStatus(true, 'Server erreichbar');
      }
      return ApiHealthStatus(
          false, 'Server antwortet mit ${response.statusCode}');
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
}
