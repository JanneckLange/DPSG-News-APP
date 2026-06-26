# API-Spezifikation

## Ziel

Basis-Endpoints für ein Express-Backend, das später Eventdaten bereitstellt.

## Endpunkte

### GET /health

Returns:
- `200 OK`
- JSON
  - `status`: `"ok"`

### GET /api/events

Returns:
- `200 OK`
- JSON
  - `events`: leerer Array als Platzhalter

## Hinweise

Dieses API-Schema ist eine einfache Grundlage und soll später um Event-Ressourcen erweitert werden.
