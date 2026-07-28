import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

/// Adress-Ergebnis der Geoapify-Autovervollstaendigung: formatierter
/// Anzeigetext plus die zugehoerigen Koordinaten.
class GeoapifyAddress {
  const GeoapifyAddress({
    required this.formatted,
    required this.lat,
    required this.lon,
  });

  final String formatted;
  final double lat;
  final double lon;

  factory GeoapifyAddress.fromJson(Map<String, dynamic> json) {
    return GeoapifyAddress(
      formatted: json['formatted'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }
}

/// Sucht Adressvorschlaege ueber die Geoapify-Autocomplete-API.
///
/// Wirft eine Exception, wenn kein GEOAPIFY_KEY konfiguriert ist oder die
/// Anfrage fehlschlaegt - der Aufrufer faengt das ab, da die Ortsauswahl
/// optional ist und ein Fehlschlag das Formular nicht blockieren soll.
Future<List<GeoapifyAddress>> autocompleteAddress(String text) async {
  final apiKey = AppConfig.geoapifyKey;
  if (apiKey.isEmpty) {
    throw Exception('No API key configured for Geoapify (GEOAPIFY_KEY)');
  }

  final uri = Uri.parse('https://api.geoapify.com/v1/geocode/autocomplete').replace(
    queryParameters: {
      'text': text,
      'lang': 'de',
      'limit': '5',
      'format': 'json',
      'apiKey': apiKey,
    },
  );

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw Exception('Failed to autocomplete address: ${response.statusCode}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final results = data['results'] as List<dynamic>? ?? [];
  return results
      .map((result) => GeoapifyAddress.fromJson(result as Map<String, dynamic>))
      .toList();
}
