part of '../remote_event_source.dart';

mixin _LayersApi on _RemoteEventSourceBase {
  Future<Map<String, dynamic>> fetchLayers() async {
    final uri = baseUrl.replace(path: '/api/layers');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.get(uri).timeout(timeout);
      stopwatch.stop();

      await logger?.logHttpRequestResult(
        source: 'events.fetchLayers',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : StateError('http_status_${response.statusCode}'),
        responseBody: response.statusCode == 200 ? null : response.body,
      );

      if (response.statusCode != 200) {
        throw RemoteEventSourceException(
          'Failed to fetch layers: ${response.statusCode}',
          statusCode: response.statusCode,
          serverMessage: _parseServerError(response.body),
        );
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.fetchLayers',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Timed out while fetching layers',
        exception: error,
        stackTrace: stackTrace,
      );
    } on SocketException catch (error, stackTrace) {
      if (stopwatch.isRunning) stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'events.fetchLayers',
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
        source: 'events.fetchLayers',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      throw RemoteEventSourceException(
        'Network error while fetching layers',
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, dynamic>> fetchAdminLayers({required String token}) async {
    final uri = baseUrl.replace(path: '/api/admin/layers');
    final response = await _client.get(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch admin layers: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLayer({
    required String token,
    required String name,
    int? parentId,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/layers');
    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({
            'name': name,
            if (parentId != null) 'parentId': parentId,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to create layer: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLayer({
    required String token,
    required int layerId,
    required String name,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/layers/$layerId');
    final response = await _client
        .patch(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({'name': name}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to update layer: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteLayer({
    required String token,
    required int layerId,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/layers/$layerId');
    final response = await _client.delete(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to delete layer: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }
}
