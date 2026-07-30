part of '../remote_event_source.dart';

mixin _GrantsApi on _RemoteEventSourceBase {
  Future<Map<String, dynamic>> addAdminLayer({
    required String token,
    required int userId,
    required int layerId,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/users/$userId/admin-layers');
    final response = await loggedRequest(
      source: 'grants.addAdminLayer',
      method: 'post',
      uri: uri,
      send: () => _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode({'layerId': layerId}),
          )
          .timeout(timeout),
    );
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to add admin layer: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> removeAdminLayer({
    required String token,
    required int userId,
    required int layerId,
  }) async {
    final uri =
        baseUrl.replace(path: '/api/admin/users/$userId/admin-layers/$layerId');
    final response = await loggedRequest(
      source: 'grants.removeAdminLayer',
      method: 'delete',
      uri: uri,
      send: () => _client.delete(
        uri,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
      ).timeout(timeout),
    );
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to remove admin layer: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }

  Future<Map<String, dynamic>> addAuthorLayerGrant({
    required String token,
    required int userId,
    required int layerId,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/users/$userId/layer-grants');
    final response = await loggedRequest(
      source: 'grants.addAuthorLayerGrant',
      method: 'post',
      uri: uri,
      send: () => _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode({'layerId': layerId}),
          )
          .timeout(timeout),
    );
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to add layer grant: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> removeAuthorLayerGrant({
    required String token,
    required int userId,
    required int layerId,
  }) async {
    final uri =
        baseUrl.replace(path: '/api/admin/users/$userId/layer-grants/$layerId');
    final response = await loggedRequest(
      source: 'grants.removeAuthorLayerGrant',
      method: 'delete',
      uri: uri,
      send: () => _client.delete(
        uri,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
      ).timeout(timeout),
    );
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to remove layer grant: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }

  Future<Map<String, dynamic>> addAuthorTopicGrant({
    required String token,
    required int userId,
    required int topicId,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/users/$userId/topic-grants');
    final response = await loggedRequest(
      source: 'grants.addAuthorTopicGrant',
      method: 'post',
      uri: uri,
      send: () => _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode({'topicId': topicId}),
          )
          .timeout(timeout),
    );
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to add topic grant: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> removeAuthorTopicGrant({
    required String token,
    required int userId,
    required int topicId,
  }) async {
    final uri =
        baseUrl.replace(path: '/api/admin/users/$userId/topic-grants/$topicId');
    final response = await loggedRequest(
      source: 'grants.removeAuthorTopicGrant',
      method: 'delete',
      uri: uri,
      send: () => _client.delete(
        uri,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
      ).timeout(timeout),
    );
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to remove topic grant: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }
}
