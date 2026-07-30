part of '../remote_event_source.dart';

mixin _DraftsApi on _RemoteEventSourceBase {
  Future<List<Map<String, dynamic>>> fetchOwnDrafts(
      {required String token}) async {
    final uri = baseUrl.replace(path: '/api/author/drafts');
    final response = await loggedRequest(
      source: 'drafts.fetchOwnDrafts',
      method: 'get',
      uri: uri,
      send: () => _client.get(uri, headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token'
      }).timeout(timeout),
    );
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
    final response = await loggedRequest(
      source: 'drafts.createDraft',
      method: 'post',
      uri: uri,
      send: () => _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(draft),
          )
          .timeout(timeout),
    );
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
    final response = await loggedRequest(
      source: 'drafts.updateDraft',
      method: 'put',
      uri: uri,
      send: () => _client
          .put(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(draft),
          )
          .timeout(timeout),
    );
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
    final response = await loggedRequest(
      source: 'drafts.deleteDraft',
      method: 'delete',
      uri: uri,
      send: () => _client.delete(
        uri,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
      ).timeout(timeout),
    );
    if (response.statusCode != 204) {
      throw RemoteEventSourceException(
        'Failed to delete draft: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
  }
}
