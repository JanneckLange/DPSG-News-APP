# API-Spezifikation

## Ziel

Basis-Endpoints für ein Express-Backend, das Eventdaten bereitstellt.

## Endpunkte

### GET /health

Returns:
- `200 OK`
- JSON
  - `status`: `"ok"`

### GET /api/events

Query-Parameter:
- `dv` (optional): Filtert Events nach Diözesanverband

Returns:
- `200 OK`
- JSON
  - `events`: Array von Event-Objekten

### POST /api/events

Request Body:
- `title`: String
- `description`: String
- `startDate`: ISO-8601 String
- `endDate`: ISO-8601 String
- `location`: String
- `dv`: String

Returns:
- `201 Created`
- JSON
  - `event`: das angelegte Event

## Hinweise

Die API nutzt PostgreSQL als persistente Datenbank. Der Server initialisiert bei Start die Tabelle `events`, falls sie nicht existiert.
