import 'package:flutter/material.dart';

/// Zeigt einen Dialog mit einer Liste waehlbarer Zielautoren (bereits
/// server-seitig nach Layer/Topic-Rechten gefiltert, siehe
/// GET /api/events/:id/eligible-authors) und liefert die gewaehlte Autor-ID
/// zurueck (null bei Abbruch). Gemeinsam genutzt vom Autor-Anfrage-Flow (#24)
/// und der Admin-Direktuebertragung (#25).
Future<int?> showTransferTargetAuthorDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> authors,
  String title = 'Zielperson auswählen',
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        if (authors.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child:
                Text('Keine berechtigte Zielperson für dieses Event gefunden.'),
          ),
        for (final author in authors)
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop((author['id'] as num).toInt()),
            child: Text(author['username'] as String? ?? ''),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
          ),
        ),
      ],
    ),
  );
}
