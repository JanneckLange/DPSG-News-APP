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

  Future<AuthorLoginSession> loginAuthor({
    required String username,
    required String password,
  }) async {
    final uri = baseUrl.replace(path: '/api/auth/login');
    final response = await _client
        .post(
          uri,
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to login author: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final author = decoded['author'] as Map<String, dynamic>;
    final accessToken =
        (decoded['accessToken'] as String?) ?? (decoded['token'] as String);
    return AuthorLoginSession(
      accessToken: accessToken,
      refreshToken: decoded['refreshToken'] as String,
      accessExpiresAt: decoded['expiresAt'] as String? ?? '',
      refreshExpiresAt: decoded['refreshExpiresAt'] as String? ?? '',
      authorId: (author['id'] as num).toInt(),
      username: author['username'] as String,
      isAdmin: author['isAdmin'] as bool? ?? false,
      requiresPasswordChange:
          decoded['requiresPasswordChange'] as bool? ?? false,
    );
  }

  Future<AuthorLoginSession> refreshAuthorSession(
      {required String refreshToken}) async {
    final uri = baseUrl.replace(path: '/api/auth/refresh');
    final response = await _client
        .post(
          uri,
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to refresh author session: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final author = decoded['author'] as Map<String, dynamic>;
    final accessToken =
        (decoded['accessToken'] as String?) ?? (decoded['token'] as String);
    return AuthorLoginSession(
      accessToken: accessToken,
      refreshToken: decoded['refreshToken'] as String,
      accessExpiresAt: decoded['expiresAt'] as String? ?? '',
      refreshExpiresAt: decoded['refreshExpiresAt'] as String? ?? '',
      authorId: (author['id'] as num).toInt(),
      username: author['username'] as String,
      isAdmin: author['isAdmin'] as bool? ?? false,
      requiresPasswordChange:
          decoded['requiresPasswordChange'] as bool? ?? false,
    );
  }

  Future<void> logoutAuthor({required String token}) async {
    final uri = baseUrl.replace(path: '/api/auth/logout');
    final response = await _client.post(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to logout author: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }

  Future<AuthorSessionState> fetchAuthorSession({required String token}) async {
    final uri = baseUrl.replace(path: '/api/auth/me');
    final response = await _client.get(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch author session: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthorSessionState(
      isAdmin: decoded['author'] is Map<String, dynamic>
          ? (decoded['author'] as Map<String, dynamic>)['isAdmin'] as bool? ??
              false
          : false,
      requiresPasswordChange:
          decoded['requiresPasswordChange'] as bool? ?? false,
    );
  }

  Future<void> changeAuthorPassword({
    required String token,
    String? oldPassword,
    required String newPassword,
  }) async {
    final uri = baseUrl.replace(path: '/api/auth/change-password');
    final payload = <String, dynamic>{'newPassword': newPassword};
    if (oldPassword != null && oldPassword.isNotEmpty) {
      payload['oldPassword'] = oldPassword;
    }
    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to change password: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
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

  Future<List<Map<String, dynamic>>> fetchOwnDrafts(
      {required String token}) async {
    final uri = baseUrl.replace(path: '/api/author/drafts');
    final response = await _client.get(uri, headers: {
      HttpHeaders.authorizationHeader: 'Bearer $token'
    }).timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch own drafts: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(json['drafts'] as List<dynamic>);
  }

  Future<Map<String, dynamic>> createDraft({
    required String token,
    required Map<String, dynamic> draft,
  }) async {
    final uri = baseUrl.replace(path: '/api/author/drafts');
    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(draft),
        )
        .timeout(timeout);
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to create draft: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['draft'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateDraft({
    required String token,
    required int draftId,
    required Map<String, dynamic> draft,
  }) async {
    final uri = baseUrl.replace(path: '/api/author/drafts/$draftId');
    final response = await _client
        .put(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(draft),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to update draft: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['draft'] as Map<String, dynamic>;
  }

  Future<void> deleteDraft({
    required String token,
    required int draftId,
  }) async {
    final uri = baseUrl.replace(path: '/api/author/drafts/$draftId');
    final response = await _client.delete(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to delete draft: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchAdminUsers(
      {required String token}) async {
    final uri = baseUrl.replace(path: '/api/admin/users');
    final response = await _client.get(uri, headers: {
      HttpHeaders.authorizationHeader: 'Bearer $token'
    }).timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch admin users: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(decoded['users'] as List<dynamic>);
  }

  Future<Map<String, dynamic>> createAdminUser({
    required String token,
    required String username,
    bool isAdmin = false,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/users');
    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({'username': username, 'isAdmin': isAdmin}),
        )
        .timeout(timeout);
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to create admin user: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> setAdminUserActive({
    required String token,
    required int userId,
    required bool isActive,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/users/$userId');
    final response = await _client
        .patch(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({'isActive': isActive}),
        )
        .timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to update user status: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }

  Future<void> deleteAdminUser({
    required String token,
    required int userId,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/users/$userId');
    final response = await _client.delete(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to delete user: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }

  Future<String> resetAdminUserPassword({
    required String token,
    required int userId,
  }) async {
    final uri =
        baseUrl.replace(path: '/api/admin/users/$userId/reset-password');
    final response = await _client.post(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to reset password: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['oneTimePassword'] as String;
  }

  Future<List<Map<String, dynamic>>> fetchEventUpdates(
      {required int eventId}) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/updates');
    final response = await _client.get(uri).timeout(timeout);
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
    this.statusCode,
    this.serverMessage,
  });

  final String message;
  final Object? exception;
  final StackTrace? stackTrace;
  final int? statusCode;

  /// Die vom Server im JSON-Body ({"error": "..."}) gelieferte Klartext-Meldung,
  /// sofern vorhanden. Nutzerfreundlicher als [message], das den rohen
  /// Response-Text enthaelt.
  final String? serverMessage;

  @override
  String toString() => 'RemoteEventSourceException: $message';
}

class AuthorLoginSession {
  AuthorLoginSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.authorId,
    required this.username,
    required this.isAdmin,
    required this.requiresPasswordChange,
  });

  final String accessToken;
  final String refreshToken;
  final String accessExpiresAt;
  final String refreshExpiresAt;
  final int authorId;
  final String username;
  final bool isAdmin;
  final bool requiresPasswordChange;
}

class AuthorSessionState {
  AuthorSessionState(
      {required this.requiresPasswordChange, required this.isAdmin});

  final bool requiresPasswordChange;
  final bool isAdmin;
}
