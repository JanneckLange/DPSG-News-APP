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

  /// Fuehrt [send] aus und protokolliert Start/Ergebnis jeder Anfrage
  /// einheitlich ueber [logger] - unabhaengig von HTTP-Methode oder
  /// erwartetem Erfolgsstatuscode. Die Interpretation des Statuscodes
  /// (welcher Code als Erfolg gilt) sowie das Mapping auf
  /// [RemoteEventSourceException] bleiben Aufgabe des Aufrufers.
  Future<http.Response> loggedRequest({
    required String source,
    required String method,
    required Uri uri,
    required Future<http.Response> Function() send,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await send();
      stopwatch.stop();
      final isError = response.statusCode >= 400;
      await logger?.logHttpRequestResult(
        source: source,
        method: method,
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        error:
            isError ? StateError('http_status_${response.statusCode}') : null,
        responseBody: isError ? response.body : null,
      );
      return response;
    } catch (error) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: source,
        method: method,
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      rethrow;
    }
  }

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

    try {
      final response = await loggedRequest(
        source: 'events.checkHealth',
        method: 'get',
        uri: uri,
        send: () => _client.get(uri).timeout(timeout),
      );

      if (response.statusCode == 200) {
        return ApiHealthStatus(true, 'Server erreichbar');
      }
      return ApiHealthStatus(
          false, 'Server antwortet mit ${response.statusCode}');
    } on TimeoutException catch (error, stackTrace) {
      throw RemoteEventSourceException(
        'Health check timed out',
        exception: error,
        stackTrace: stackTrace,
      );
    } on SocketException catch (error, stackTrace) {
      throw RemoteEventSourceException(
        'Unable to reach health endpoint',
        exception: error,
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      throw RemoteEventSourceException(
        'Network error during health check',
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }
}
