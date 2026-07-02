# Architektur-Spezifikation

## Ziel

Beschreibe die technische Struktur der aktuellen Implementierung.

## Bereiche

- `app/`: Flutter-Frontend
- `server/`: Express-Backend

## Schnittstelle

- `app/` konsumiert `server/` über REST-API-Endpunkte wie `GET /api/events`, `POST /api/auth/login` und `GET /api/author/events`.
- Der Server bietet Health-Checks, Autoren-Login und eigene Event-CRUD-Endpunkte.

## Autoren-Flow

- Login erfolgt mit Username und Passwort.
- Einmalpasswörter sind für den Erstzugang vorgesehen.
- Passwortwechsel kann in der App erfolgen.
- Nach Inaktivität von 60 Sekunden wird der Autorenbereich per Biometrie neu entsperrt.

## Projektorganisation

- Konfiguration: getrennte Env-Vorlagen unter `app/.env.example` und `server/.env.example`
- Dokumentation: `doc/`
- Spezifikation: `spec/`
