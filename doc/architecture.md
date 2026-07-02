# Architektur

## Systemübersicht

Das Repo ist als monorepo mit zwei Hauptbereichen aufgebaut:

- `app/`: Flutter-Frontend
- `server/`: Express-Backend

## Trennung

- Die App stellt die Benutzerschnittstelle dar und konsumiert später die Backend-API.
- Der Server liefert Health-Checks, öffentlichen Event-Feed sowie Autoren-Login und eigene Event-CRUD-Endpunkte.
- Der Autorenbereich ist auf eigene Events begrenzt.

## Zukunft

Spätere Erweiterungen können beinhalten:

- REST-API für Veranstaltungen
- Authentifizierung und Berechtigungen
- Persistente Datenbank für Eventdaten
- Push-Benachrichtigungen im Frontend
