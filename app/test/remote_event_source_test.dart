import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';

void main() {
  final baseUrl = Uri.parse('http://localhost:3000');

  test('fetchEvents returns parsed events on HTTP 200', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"events":[{"title":"Test Event","location":"Testort","layerId":3}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final events = await source.fetchEvents();

    expect(events, isA<List<Map<String, dynamic>>>());
    expect(events, hasLength(1));
    expect(events.first['title'], 'Test Event');
  });

  test('fetchEvents throws RemoteEventSourceException on non-200 response',
      () async {
    final client = MockClient((request) async {
      return http.Response('Not found', 404);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.fetchEvents(),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.message.contains('Failed to fetch events')),
        ),
      ),
    );
  });

  test('fetchEvents throws RemoteEventSourceException on timeout', () async {
    final client = MockClient((request) {
      return Future<http.Response>.delayed(
        const Duration(seconds: 2),
        () => http.Response('Timeout', 200),
      );
    });

    final source = RemoteEventSource(
      baseUrl: baseUrl,
      client: client,
      timeout: const Duration(milliseconds: 100),
    );

    expect(
      source.fetchEvents(),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.message.contains('Timed out while fetching events')),
        ),
      ),
    );
  });

  test('fetchEvents throws RemoteEventSourceException on network unreachable',
      () async {
    final client = MockClient((request) async {
      throw const SocketException('Failed host lookup');
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.fetchEvents(),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.message.contains('Unable to reach the event server')),
        ),
      ),
    );
  });

  test('fetchLayers returns parsed layers on HTTP 200', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/layers');
      expect(request.method, 'GET');
      return http.Response(
        '{"layers":[{"id":1,"name":"Bundesverband DPSG","type":"bundesverband","parentId":null}],"lastChange":"2026-01-01T00:00:00.000Z"}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final result = await source.fetchLayers();

    expect(result['lastChange'], '2026-01-01T00:00:00.000Z');
    expect((result['layers'] as List).first['name'], 'Bundesverband DPSG');
  });

  test('fetchLayers throws RemoteEventSourceException on non-200 response',
      () async {
    final client = MockClient((request) async {
      return http.Response('Server error', 500);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.fetchLayers(),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.message.contains('Failed to fetch layers')),
        ),
      ),
    );
  });

  test('fetchTopics returns parsed topics on HTTP 200', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/topics');
      expect(request.url.queryParameters['layerId'], '3');
      expect(request.method, 'GET');
      return http.Response(
        '{"topics":[{"id":1,"name":"Stufenaktion","layerId":3,"createdAt":"2026-01-01T00:00:00.000Z","updatedAt":"2026-01-01T00:00:00.000Z"}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final result = await source.fetchTopics(layerId: 3);

    expect((result['topics'] as List).first['name'], 'Stufenaktion');
  });

  test('fetchTopics throws RemoteEventSourceException on non-200 response',
      () async {
    final client = MockClient((request) async {
      return http.Response('Server error', 500);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.fetchTopics(),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.message.contains('Failed to fetch topics')),
        ),
      ),
    );
  });

  test('createTopic posts to /api/admin/topics and returns created topic',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/admin/topics');
      expect(request.method, 'POST');
      return http.Response(
        '{"topic":{"id":2,"name":"Neues Thema","layerId":3,"createdAt":"2026-01-01T00:00:00.000Z","updatedAt":"2026-01-01T00:00:00.000Z"}}',
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final result = await source.createTopic(
      token: 'token',
      name: 'Neues Thema',
      layerId: 3,
    );

    expect(result['topic']['id'], 2);
  });

  test('createTopic throws RemoteEventSourceException on non-201 response',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"error":"A topic with this name already exists for this layer"}',
        409,
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.createTopic(token: 'token', name: 'Duplikat', layerId: 3),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.serverMessage ==
              'A topic with this name already exists for this layer'),
        ),
      ),
    );
  });

  test('updateTopic patches /api/admin/topics/:id and returns updated topic',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/admin/topics/5');
      expect(request.method, 'PATCH');
      return http.Response(
        '{"topic":{"id":5,"name":"Umbenannt","layerId":3,"createdAt":"2026-01-01T00:00:00.000Z","updatedAt":"2026-01-01T00:00:00.000Z"}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final result = await source.updateTopic(
      token: 'token',
      topicId: 5,
      name: 'Umbenannt',
    );

    expect(result['topic']['name'], 'Umbenannt');
  });

  test('updateTopic throws RemoteEventSourceException on non-200 response',
      () async {
    final client = MockClient((request) async {
      return http.Response('{"error":"Topic not found"}', 404);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.updateTopic(token: 'token', topicId: 5, name: 'x'),
      throwsA(isA<RemoteEventSourceException>()),
    );
  });

  test('deleteTopic sends DELETE to /api/admin/topics/:id', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/admin/topics/9');
      expect(request.method, 'DELETE');
      return http.Response('', 204);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    await source.deleteTopic(token: 'token', topicId: 9);
  });

  test(
      'deleteTopic throws RemoteEventSourceException with server message when topic is in use',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"error":"Topic is referenced by events or drafts and cannot be deleted"}',
        409,
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.deleteTopic(token: 'token', topicId: 9),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.serverMessage ==
              'Topic is referenced by events or drafts and cannot be deleted'),
        ),
      ),
    );
  });

  test('fetchOwnDrafts returns parsed drafts on HTTP 200', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/author/drafts');
      expect(request.method, 'GET');
      return http.Response(
        '{"drafts":[{"id":1,"title":"Entwurf","timeUntilDeletion":86400}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final drafts = await source.fetchOwnDrafts(token: 'token');

    expect(drafts, hasLength(1));
    expect(drafts.first['title'], 'Entwurf');
  });

  test('fetchOwnDrafts throws RemoteEventSourceException on non-200 response',
      () async {
    final client = MockClient((request) async {
      return http.Response('Unauthorized', 401);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.fetchOwnDrafts(token: 'token'),
      throwsA(isA<RemoteEventSourceException>()),
    );
  });

  test('createDraft posts to /api/author/drafts and returns created draft',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/author/drafts');
      expect(request.method, 'POST');
      return http.Response(
        '{"draft":{"id":2,"title":"Neuer Entwurf"}}',
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final draft = await source.createDraft(
      token: 'token',
      draft: {'title': 'Neuer Entwurf'},
    );

    expect(draft['id'], 2);
  });

  test('createDraft throws RemoteEventSourceException on non-201 response',
      () async {
    final client = MockClient((request) async {
      return http.Response('Bad request', 400);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.createDraft(token: 'token', draft: {'title': ''}),
      throwsA(isA<RemoteEventSourceException>()),
    );
  });

  test('updateDraft puts to /api/author/drafts/:id and returns updated draft',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/author/drafts/5');
      expect(request.method, 'PUT');
      return http.Response(
        '{"draft":{"id":5,"title":"Aktualisiert"}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final draft = await source.updateDraft(
      token: 'token',
      draftId: 5,
      draft: {'title': 'Aktualisiert'},
    );

    expect(draft['title'], 'Aktualisiert');
  });

  test('updateDraft throws RemoteEventSourceException on non-200 response',
      () async {
    final client = MockClient((request) async {
      return http.Response('Not found', 404);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.updateDraft(token: 'token', draftId: 5, draft: {'title': 'x'}),
      throwsA(isA<RemoteEventSourceException>()),
    );
  });

  test('deleteDraft sends DELETE to /api/author/drafts/:id', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/author/drafts/7');
      expect(request.method, 'DELETE');
      return http.Response('', 204);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    await source.deleteDraft(token: 'token', draftId: 7);
  });

  test('deleteDraft throws RemoteEventSourceException on non-204 response',
      () async {
    final client = MockClient((request) async {
      return http.Response('Not found', 404);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.deleteDraft(token: 'token', draftId: 7),
      throwsA(isA<RemoteEventSourceException>()),
    );
  });

  test(
      'createDraft exposes the server error message and status code from a JSON error body',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"error":"Missing required draft fields"}',
        400,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    await expectLater(
      source.createDraft(token: 'token', draft: {}),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.serverMessage == 'Missing required draft fields' &&
              e.statusCode == 400),
        ),
      ),
    );
  });

  test(
      'createOwnEvent falls back to null serverMessage when the body is not JSON',
      () async {
    final client = MockClient((request) async {
      return http.Response('Internal Server Error', 500);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    await expectLater(
      source.createOwnEvent(token: 'token', event: {'title': 'x'}),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.serverMessage == null && e.statusCode == 500),
        ),
      ),
    );
  });

  test('fetchEventUpdates returns parsed updates on HTTP 200', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/events/42/updates');
      expect(request.method, 'GET');
      return http.Response(
        '{"updates":[{"id":1,"message":"Hallo","authorUsername":"max"}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final updates = await source.fetchEventUpdates(eventId: 42);

    expect(updates, hasLength(1));
    expect(updates.first['message'], 'Hallo');
  });

  test(
      'fetchEventUpdates throws RemoteEventSourceException on non-200 response',
      () async {
    final client = MockClient((request) async {
      return http.Response('Not found', 404);
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    expect(
      source.fetchEventUpdates(eventId: 999),
      throwsA(isA<RemoteEventSourceException>()),
    );
  });

  test(
      'createEventUpdate posts to /api/events/:id/updates and returns created update',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/events/42/updates');
      expect(request.method, 'POST');
      expect(jsonDecode(request.body), {'message': 'Neues Update'});
      return http.Response(
        '{"update":{"id":5,"message":"Neues Update","authorUsername":"max"}}',
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);
    final update = await source.createEventUpdate(
      token: 'token',
      eventId: 42,
      message: 'Neues Update',
    );

    expect(update['id'], 5);
    expect(update['message'], 'Neues Update');
  });

  test(
      'createEventUpdate exposes the server error message on a JSON error body',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"error":"Missing update message"}',
        400,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = RemoteEventSource(baseUrl: baseUrl, client: client);

    await expectLater(
      source.createEventUpdate(token: 'token', eventId: 42, message: ''),
      throwsA(
        allOf(
          isA<RemoteEventSourceException>(),
          predicate((RemoteEventSourceException e) =>
              e.serverMessage == 'Missing update message' &&
              e.statusCode == 400),
        ),
      ),
    );
  });
}
