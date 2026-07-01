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
3. Firebase Admin Key lokal ausserhalb des Repos ablegen und `GOOGLE_APPLICATION_CREDENTIALS` auf den absoluten Pfad setzen
4. Server bauen und starten:

```bash
npm run build
npm start
```

Beispiel in `.env`:

```bash
GOOGLE_APPLICATION_CREDENTIALS=/Users/<you>/secrets/firebase-dev.json
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
- Firebase Service Account Keys duerfen nicht im Repository liegen.

### Firebase Prod Key auf Server tauschen

1. Neuen JSON-Key im Firebase-Prod-Projekt erzeugen.
2. Datei auf den Server nach `/opt/dpsg-news/secrets/firebase-service-account.json` kopieren.
3. Dateirechte setzen (`chmod 600`) und Besitzer auf den Deploy-User setzen.
4. Server-Container neu starten, damit der Key neu eingelesen wird:

```bash
cd /opt/dpsg-news
docker compose -f docker-compose.server.yml up -d server
```

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

- `GET /health` — Health-Check inkl. Build-Metadaten (`buildTimeUtc`, `gitShaShort`, `gitRef`)
- `GET /api/events` — Events abrufen
- `GET /api/events?dv=...` — Events nach Diözesanverband filtern
- `POST /api/events` — Event anlegen

## Build-Stand in Logs

Beim Serverstart wird der Build-Stand geloggt:

- `buildTimeUtc` (UTC)
- `gitShaShort` (auf 12 Zeichen gekuerzt)
- `gitRef`

In Produktion setzt die GitHub-Action diese Werte beim Docker-Build.
Lokal werden ohne gesetzte Werte sinnvolle Fallbacks verwendet (`unknown`, `local-dev`).

## Logging-Format

Der Server nutzt ein Dual-Format fuer Logs:

- Development: gut lesbare Zeilen mit Zeitstempel, Service und Feldern
- Production: JSON-Logs fuer Monitoring und zentrale Auswertung

Der Service-Name ist fest auf `dpsg-news-server` gesetzt.

## Request ID

Jeder Request bekommt eine `x-request-id`:

- Wenn der Client `x-request-id` sendet, wird dieser Wert uebernommen
- Ohne Header wird serverseitig eine UUID erzeugt
- Die finale `x-request-id` wird immer im Response-Header gesetzt

Request- und Error-Logs enthalten die `requestId` zur einfacheren Korrelation.

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
