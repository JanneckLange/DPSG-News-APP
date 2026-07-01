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
        '{"events":[{"title":"Test Event","location":"Testort","dv":"Köln"}]}',
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

  test('fetchEvents throws RemoteEventSourceException on non-200 response', () async {
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

  test('fetchEvents throws RemoteEventSourceException on network unreachable', () async {
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
}
