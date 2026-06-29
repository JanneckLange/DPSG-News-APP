import 'dart:convert';

import 'package:http/http.dart' as http;

class RemoteEventSource {
  final Uri baseUrl;

  RemoteEventSource({required this.baseUrl});

  Future<List<Map<String, dynamic>>> fetchEvents() async {
    final response = await http.get(baseUrl.replace(path: '/api/events'));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch events');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(json['events'] as List<dynamic>);
  }
}
