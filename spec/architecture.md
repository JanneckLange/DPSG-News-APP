# Architektur-Spezifikation

## Ziel

Beschreibe die technische Struktur der Basisimplementierung.

## Bereiche

- `app/`: Flutter-Frontend
- `server/`: Express-Backend

## Schnittstelle

- `app/` konsumiert später `server/` über REST-API-Endpunkte wie `GET /api/events`.
- Der Server bietet heute nur einen `GET /health`-Endpunkt und einen Platzhalter für `GET /api/events`.

## Projektorganisation

- Konfiguration: Root-`.env.example` für gemeinsame Variablen
- Dokumentation: `doc/`
- Spezifikation: `spec/`
