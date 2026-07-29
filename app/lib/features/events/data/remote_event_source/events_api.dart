part of '../remote_event_source.dart';

mixin _EventsApi on _RemoteEventSourceBase {
  Future<List<Map<String, dynamic>>> fetchEvents({String? token}) async {
    final uri = baseUrl.replace(path: '/api/events');
    final stopwatch = Stopwatch()..start();

    try {
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
      final response =
          await _client.get(uri, headers: headers).timeout(timeout);
      stopwatch.stop();

      await logger?.logHttpRequestResult(
        source: 'events.fetchEvents',
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
          'Failed to fetch events: ${response.statusCode}',
          statusCode: response.statusCode,
          serverMessage: _parseServerError(response.body),
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
        error: response.statusCode == 201
            ? null
            : StateError('http_status_${response.statusCode}'),
        responseBody: response.statusCode == 201 ? null : response.body,
      );

      if (response.statusCode != 201) {
        throw RemoteEventSourceException(
          'Failed to create event: ${response.statusCode} ${response.body}',
          statusCode: response.statusCode,
          serverMessage: _parseServerError(response.body),
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

  Future<List<Map<String, dynamic>>> fetchOwnEvents(
      {required String token}) async {
    final uri = baseUrl.replace(path: '/api/author/events');
    final response = await _client.get(uri, headers: {
      HttpHeaders.authorizationHeader: 'Bearer $token'
    }).timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch own events: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(json['events'] as List<dynamic>);
  }

  Future<Map<String, dynamic>> createOwnEvent({
    required String token,
    required Map<String, dynamic> event,
  }) async {
    final uri = baseUrl.replace(path: '/api/author/events');
    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(event),
        )
        .timeout(timeout);
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to create own event: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['event'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEvent({
    required String token,
    required int eventId,
    required Map<String, dynamic> event,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId');
    final response = await _client
        .put(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(event),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to update event: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['event'] as Map<String, dynamic>;
  }

  Future<void> deleteEvent({
    required String token,
    required int eventId,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId');
    final response = await _client.delete(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to delete event: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }

  Future<Map<String, dynamic>> updateOwnEvent({
    required String token,
    required int eventId,
    required Map<String, dynamic> event,
  }) async {
    final uri = baseUrl.replace(path: '/api/author/events/$eventId');
    final response = await _client
        .put(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(event),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to update own event: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['event'] as Map<String, dynamic>;
  }

  Future<void> deleteOwnEvent({
    required String token,
    required int eventId,
  }) async {
    final uri = baseUrl.replace(path: '/api/author/events/$eventId');
    final response = await _client.delete(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to delete own event: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchEventUpdates(
      {required int eventId, String? token}) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/updates');
    final response = await _client
        .get(
          uri,
          headers: token == null
              ? null
              : {HttpHeaders.authorizationHeader: 'Bearer $token'},
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch event updates: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(json['updates'] as List<dynamic>);
  }

  Future<List<Map<String, dynamic>>> fetchEventHistory(
      {required int eventId, String? token}) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/history');
    final response = await _client
        .get(
          uri,
          headers: token == null
              ? null
              : {HttpHeaders.authorizationHeader: 'Bearer $token'},
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch event history: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(json['history'] as List<dynamic>);
  }

  Future<Map<String, dynamic>> createEventUpdate({
    required String token,
    required int eventId,
    required String message,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/updates');
    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({'message': message}),
        )
        .timeout(timeout);
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to create event update: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['update'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEventUpdate({
    required String token,
    required int eventId,
    required int updateId,
    required String message,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/updates/$updateId');
    final response = await _client
        .put(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({'message': message}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to update event update: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['update'] as Map<String, dynamic>;
  }

  Future<void> deleteEventUpdate({
    required String token,
    required int eventId,
    required int updateId,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/updates/$updateId');
    final response = await _client.delete(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to delete event update: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }
}
