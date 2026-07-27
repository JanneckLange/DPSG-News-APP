part of '../remote_event_source.dart';

mixin _TopicsApi on _RemoteEventSourceBase {
  Future<Map<String, dynamic>> fetchTopics({int? layerId}) async {
    final uri = baseUrl.replace(
      path: '/api/topics',
      queryParameters: layerId != null ? {'layerId': '$layerId'} : null,
    );
    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch topics: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTopic({
    required String token,
    required String name,
    required int layerId,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/topics');
    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({'name': name, 'layerId': layerId}),
        )
        .timeout(timeout);
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to create topic: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTopic({
    required String token,
    required int topicId,
    required String name,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/topics/$topicId');
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
        'Failed to update topic: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteTopic({
    required String token,
    required int topicId,
  }) async {
    final uri = baseUrl.replace(path: '/api/admin/topics/$topicId');
    final response = await _client.delete(
      uri,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to delete topic: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }
}
