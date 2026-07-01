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

## Deployment (Linux + Docker)

Automatisierter Ablauf:

- Bei jedem Push auf `main` baut GitHub Actions ein neues Server-Image.
- Das Image wird nach Docker Hub (`sapza/dpsgnews`) gepusht.
- Anschliessend erfolgt Deployment per SSH auf den Linux-Host.
- Deployment-Dateien (`docker-compose.server.yml`, `Caddyfile`) werden dabei automatisch auf den Host synchronisiert.

Workflow-Datei:

- `.github/workflows/server-deploy-main.yml`

Voraussetzungen auf dem Host:

- `/opt/dpsg-news/docker-compose.server.yml`
- `/opt/dpsg-news/Caddyfile`
- `/opt/dpsg-news/.env`
- `/opt/dpsg-news/secrets/`

Ein Compose-Template liegt unter:

- `server/deploy/docker-compose.server.yml`

Benoetigte GitHub Secrets:

- `DOCKERHUB_TOKEN`
- `SSH_HOST`
- `SSH_USER`
- `SSH_PRIVATE_KEY`
- `SSH_PORT`

Wichtig:

- Runtime-Secrets gehoeren auf den Linux-Host, nicht in das Docker-Image.
- Secret-Dateien nur read-only mounten.
- HTTPS laeuft automatisch ueber Caddy (Let's Encrypt), wenn die Domain auf die Server-IP zeigt.

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
