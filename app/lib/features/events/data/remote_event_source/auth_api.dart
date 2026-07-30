part of '../remote_event_source.dart';

mixin _AuthApi on _RemoteEventSourceBase {
  Future<AuthorLoginSession> loginAuthor({
    required String username,
    required String password,
  }) async {
    final uri = baseUrl.replace(path: '/api/auth/login');
    final response = await loggedRequest(
      source: 'auth.loginAuthor',
      method: 'post',
      uri: uri,
      send: () => _client
          .post(
            uri,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(timeout),
    );
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
      layerGrantIds: _parseIntList(author['layerGrantIds']),
      topicGrantIds: _parseIntList(author['topicGrantIds']),
    );
  }

  Future<AuthorLoginSession> refreshAuthorSession(
      {required String refreshToken}) async {
    final uri = baseUrl.replace(path: '/api/auth/refresh');
    final response = await loggedRequest(
      source: 'auth.refreshAuthorSession',
      method: 'post',
      uri: uri,
      send: () => _client
          .post(
            uri,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(timeout),
    );
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
      layerGrantIds: _parseIntList(author['layerGrantIds']),
      topicGrantIds: _parseIntList(author['topicGrantIds']),
    );
  }

  Future<void> logoutAuthor({required String token}) async {
    final uri = baseUrl.replace(path: '/api/auth/logout');
    final response = await loggedRequest(
      source: 'auth.logoutAuthor',
      method: 'post',
      uri: uri,
      send: () => _client.post(
        uri,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
      ).timeout(timeout),
    );
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
    final response = await loggedRequest(
      source: 'auth.fetchAuthorSession',
      method: 'get',
      uri: uri,
      send: () => _client.get(
        uri,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
      ).timeout(timeout),
    );
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch author session: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final author = decoded['author'] is Map<String, dynamic>
        ? decoded['author'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return AuthorSessionState(
      isAdmin: author['isAdmin'] as bool? ?? false,
      requiresPasswordChange:
          decoded['requiresPasswordChange'] as bool? ?? false,
      layerGrantIds: _parseIntList(author['layerGrantIds']),
      topicGrantIds: _parseIntList(author['topicGrantIds']),
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
    final response = await loggedRequest(
      source: 'auth.changeAuthorPassword',
      method: 'post',
      uri: uri,
      send: () => _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout),
    );
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to change password: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }
}

List<int> _parseIntList(dynamic value) {
  if (value is! List) return <int>[];
  return value.whereType<num>().map((v) => v.toInt()).toList();
}
