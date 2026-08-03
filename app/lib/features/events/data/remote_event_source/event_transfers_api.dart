part of '../remote_event_source.dart';

mixin _EventTransfersApi on _RemoteEventSourceBase {
  Future<List<Map<String, dynamic>>> fetchEligibleTransferAuthors({
    required String token,
    required int eventId,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/eligible-authors');
    final response = await loggedRequest(
      source: 'eventTransfers.fetchEligibleTransferAuthors',
      method: 'get',
      uri: uri,
      send: () => _client.get(uri, headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token'
      }).timeout(timeout),
    );
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch eligible authors: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(json['authors'] as List<dynamic>);
  }

  Future<Map<String, dynamic>> createEventTransferRequest({
    required String token,
    required int eventId,
    required int toAuthorId,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/transfer-requests');
    final response = await loggedRequest(
      source: 'eventTransfers.createEventTransferRequest',
      method: 'post',
      uri: uri,
      send: () => _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode({'toAuthorId': toAuthorId}),
          )
          .timeout(timeout),
    );
    if (response.statusCode != 201) {
      throw RemoteEventSourceException(
        'Failed to create transfer request: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['request'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchOutgoingEventTransferRequests({
    required String token,
    required int eventId,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/transfer-requests');
    final response = await loggedRequest(
      source: 'eventTransfers.fetchOutgoingEventTransferRequests',
      method: 'get',
      uri: uri,
      send: () => _client.get(uri, headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token'
      }).timeout(timeout),
    );
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch transfer requests: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(json['requests'] as List<dynamic>);
  }

  Future<List<Map<String, dynamic>>> fetchIncomingEventTransferRequests({
    required String token,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/transfer-requests/incoming');
    final response = await loggedRequest(
      source: 'eventTransfers.fetchIncomingEventTransferRequests',
      method: 'get',
      uri: uri,
      send: () => _client.get(uri, headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token'
      }).timeout(timeout),
    );
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to fetch incoming transfer requests: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(json['requests'] as List<dynamic>);
  }

  Future<Map<String, dynamic>> acceptEventTransferRequest({
    required String token,
    required int requestId,
  }) async {
    final uri = baseUrl.replace(
        path: '/api/events/transfer-requests/$requestId/accept');
    final response = await loggedRequest(
      source: 'eventTransfers.acceptEventTransferRequest',
      method: 'post',
      uri: uri,
      send: () => _client.post(uri, headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token'
      }).timeout(timeout),
    );
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to accept transfer request: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectEventTransferRequest({
    required String token,
    required int requestId,
  }) async {
    final uri = baseUrl.replace(
        path: '/api/events/transfer-requests/$requestId/reject');
    final response = await loggedRequest(
      source: 'eventTransfers.rejectEventTransferRequest',
      method: 'post',
      uri: uri,
      send: () => _client.post(uri, headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token'
      }).timeout(timeout),
    );
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to reject transfer request: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['request'] as Map<String, dynamic>;
  }

  /// Admin-Direktuebertragung ohne Zustimmung der Zielperson (#23/#25).
  Future<Map<String, dynamic>> transferEventDirectly({
    required String token,
    required int eventId,
    required int toAuthorId,
  }) async {
    final uri = baseUrl.replace(path: '/api/events/$eventId/transfer');
    final response = await loggedRequest(
      source: 'eventTransfers.transferEventDirectly',
      method: 'post',
      uri: uri,
      send: () => _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode({'toAuthorId': toAuthorId}),
          )
          .timeout(timeout),
    );
    if (response.statusCode != 200) {
      throw RemoteEventSourceException(
        'Failed to transfer event: ${response.statusCode} ${response.body}',
        statusCode: response.statusCode,
        serverMessage: _parseServerError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['event'] as Map<String, dynamic>;
  }
}
