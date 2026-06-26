# Architektur

## Systemübersicht

Das Repo ist als monorepo mit zwei Hauptbereichen aufgebaut:

- `app/`: Flutter-Frontend
- `server/`: Express-Backend

## Trennung

- Die App stellt die Benutzerschnittstelle dar und konsumiert später die Backend-API.
- Der Server liefert minimale Endpunkte für Health-Checks und Beispieldaten.
- Die fachliche Event-Logik ist in diesem Scaffold noch nicht implementiert.

## Zukunft

Spätere Erweiterungen können beinhalten:

- REST-API für Veranstaltungen
- Authentifizierung und Berechtigungen
- Persistente Datenbank für Eventdaten
- Push-Benachrichtigungen im Frontend
