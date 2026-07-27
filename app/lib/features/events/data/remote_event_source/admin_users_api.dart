part of '../remote_event_source.dart';

mixin _AdminUsersApi on _RemoteEventSourceBase {
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

  Future<List<Map<String, dynamic>>> fetchLayerAdmins({
    required String token,
    required int layerId,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/layers/$layerId/admins');
    final response = await _client.get(uri, headers: {
      HttpHeaders.authorizationHeader: 'Bearer $token'
    }).timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch layer admins: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(decoded['admins'] as List<dynamic>);
  }

  Future<Map<String, dynamic>> createAdminUser({
    required String token,
    required String username,
    bool isAdmin = false,
    List<int>? layerIds,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/users');
    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({
            'username': username,
            'isAdmin': isAdmin,
            if (layerIds != null) 'layerIds': layerIds,
          }),
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
}
