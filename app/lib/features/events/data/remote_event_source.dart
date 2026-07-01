import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class RemoteEventSource {
  RemoteEventSource({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;
  final Duration timeout;

  Future<List<Map<String, dynamic>>> fetchEvents() async {
    try {
      final response = await _client
          .get(baseUrl.replace(path: '/api/events'))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw RemoteEventSourceException(
          'Failed to fetch events: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(json['events'] as List<dynamic>);
    } on TimeoutException catch (error, stackTrace) {
      throw RemoteEventSourceException(
        'Timed out while fetching events',
        exception: error,
        stackTrace: stackTrace,
      );
    } on SocketException catch (error, stackTrace) {
      throw RemoteEventSourceException(
        'Unable to reach the event server',
        exception: error,
        stackTrace: stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      throw RemoteEventSourceException(
        'Received invalid response from server',
        exception: error,
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      throw RemoteEventSourceException(
        'Network error while fetching events',
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class RemoteEventSourceException implements Exception {
  RemoteEventSourceException(
    this.message, {
    this.exception,
    this.stackTrace,
  });

  final String message;
  final Object? exception;
  final StackTrace? stackTrace;

  @override
  String toString() => 'RemoteEventSourceException: $message';
}
