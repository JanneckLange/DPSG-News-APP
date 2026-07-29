import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/services/logging_service.dart';
import 'geoapify_service.dart';

/// Sucht Adressvorschlaege ueber die OpenStreetMap-Nominatim-API.
///
/// Dient als API-key-freier Fallback, falls Geoapify nicht konfiguriert
/// oder nicht erreichbar ist. Nominatim ist ein kostenloser Community-Dienst
/// mit strikter Nutzungsrichtlinie (max. 1 Anfrage/Sekunde, kein
/// automatisiertes Massen-Scraping, Pflicht-User-Agent) - fuer das
/// debounced Autocomplete einzelner Autoren unkritisch, sollte bei
/// spuerbarem Traffic aber neu bewertet werden (z. B. eigener Host).
/// Siehe https://operations.osmfoundation.org/policies/nominatim/
Future<List<GeoapifyAddress>> autocompleteAddressNominatim(
  String text, {
  LoggingService? logger,
}) async {
  final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
    queryParameters: {
      'q': text,
      'format': 'jsonv2',
      'addressdetails': '0',
      'limit': '5',
      'accept-language': 'de',
    },
  );

  await logger?.logHttpRequestStart(
    source: 'nominatim.autocomplete',
    method: 'get',
    uri: uri,
  );

  final stopwatch = Stopwatch()..start();
  try {
    final response = await http.get(
      uri,
      headers: {'User-Agent': 'DPSGNewsApp (dev@jannecklange.de)'},
    );
    stopwatch.stop();
    if (response.statusCode != 200) {
      await logger?.logHttpRequestResult(
        source: 'nominatim.autocomplete',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw Exception('Failed to autocomplete address via Nominatim: ${response.statusCode}');
    }

    await logger?.logHttpRequestResult(
      source: 'nominatim.autocomplete',
      method: 'get',
      uri: uri,
      durationMs: stopwatch.elapsedMilliseconds,
      statusCode: response.statusCode,
    );

    final results = jsonDecode(response.body) as List<dynamic>;
    return results
        .map((result) => _fromNominatimJson(result as Map<String, dynamic>))
        .toList();
  } catch (error) {
    if (stopwatch.isRunning) {
      stopwatch.stop();
      await logger?.logHttpRequestResult(
        source: 'nominatim.autocomplete',
        method: 'get',
        uri: uri,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
    }
    rethrow;
  }
}

GeoapifyAddress _fromNominatimJson(Map<String, dynamic> json) {
  return GeoapifyAddress(
    formatted: json['display_name'] as String,
    lat: double.parse(json['lat'] as String),
    lon: double.parse(json['lon'] as String),
  );
}
