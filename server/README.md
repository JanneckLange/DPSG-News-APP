# Server

Express-Backend für die DPSG News APP.

## Installation

```bash
cd server
npm install
```

## Lokaler Start

1. Eine lokale Postgres-Instanz starten (z. B. mit Docker Compose oder lokal installiertem Postgres)
2. Umgebungsvariablen in `.env` konfigurieren oder `DATABASE_URL` setzen
3. Server bauen und starten:

```bash
npm run build
npm start
```

## Docker Compose

Im Projektstamm kann die gesamte Produktivumgebung gestartet werden:

```bash
docker compose up --build
```

Der Server ist dann auf `http://localhost:3000` erreichbar.

## Testen

Für Unit- und E2E-Tests nutzt der Server `jest` und `supertest`.

```bash
npm run test:unit
npm run test:e2e
npm test
```

E2E-Tests erwarten eine erreichbare PostgreSQL-Testdatenbank, z. B. über

```bash
docker compose up -d postgres-test
```

und nutzen dann die lokale Server-Implementierung mit `TEST_DATABASE_URL=postgres://dpsg:dpsg@localhost:5433/dpsg_news_test`.

## Endpunkte

- `GET /health` — Health-Check
- `GET /api/events` — Events abrufen
- `GET /api/events?dv=...` — Events nach Diözesanverband filtern
- `POST /api/events` — Event anlegen

## Event-Datenmodell

Ein Event enthält:

- `title`
- `description`
- `startDate`
- `endDate`
- `location`
- `dv`
- `createdAt`
- `updatedAt`
