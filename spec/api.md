# API-Spezifikation

## Ziel

Express-Backend für Events und Autoren-Login.

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

### Auth

#### POST /api/auth/login

Body:
- `username`
- `password`

Returns:
- `200 OK`
- `token`
- `author`
- `requiresPasswordChange`

#### POST /api/auth/logout

Header:
- `Authorization: Bearer <token>`

Returns:
- `204 No Content`

#### GET /api/auth/me

Header:
- `Authorization: Bearer <token>`

Returns:
- `200 OK`
- `author`
- `requiresPasswordChange`

#### POST /api/auth/change-password

Header:
- `Authorization: Bearer <token>`

Body:
- `oldPassword` optional bei Erstpasswort
- `newPassword`

Returns:
- `204 No Content`

### Autoren-Events

#### GET /api/author/events
#### POST /api/author/events
#### PUT /api/author/events/:id
#### DELETE /api/author/events/:id

Alle Endpunkte nutzen den Bearer-Token und betreffen nur eigene Events.

### Öffentliche Events

#### POST /api/events
#### DELETE /api/events

Diese Endpunkte verlangen ebenfalls einen Autoren-Token.

## Hinweise

Die API nutzt PostgreSQL als persistente Datenbank. Der Server initialisiert `authors`, `author_sessions` und `events` beim Start.
