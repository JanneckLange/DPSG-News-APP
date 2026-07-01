# CI/CD Prozess (iOS + Server)

## Zielbild

- iOS Build ueber Xcode Cloud
- Server Build/Deploy ueber GitHub Actions bei jedem Push auf `main`
- Qualitaetschecks in GitHub Actions als Warnung (non-blocking)

## Workflows

### 1) Quality Soft Checks

Datei: `.github/workflows/quality-soft-checks.yml`

Ablauf:

- App: `flutter analyze`, `flutter test --coverage`, Coverage-Schwelle 80%
- Server: `npm run verify` (lint + coverage threshold)
- Fehler markieren den Job als Warnung, blockieren Deploy aber nicht

### 2) Server Deploy Main

Datei: `.github/workflows/server-deploy-main.yml`

Trigger:

- Push auf `main`

Ablauf:

1. Docker Image fuer `server/` bauen
2. Push zu Docker Hub (`latest` und SHA-Tag)
3. SSH auf Linux Host
4. Deployment-Dateien auf den Host synchronisieren (`docker-compose.server.yml`, `Caddyfile`)
5. `docker compose up -d` mit neuem Image

## GitHub Secrets

Erforderlich:

- DOCKERHUB_TOKEN
- SSH_HOST
- SSH_USER
- SSH_PRIVATE_KEY
- SSH_PORT

Hinweis: Das Repository ist fest auf `sapza/dpsgnews` konfiguriert.

## Linux Host Struktur

Empfohlene Struktur:

- `/opt/dpsg-news/docker-compose.server.yml`
- `/opt/dpsg-news/Caddyfile`
- `/opt/dpsg-news/.env`
- `/opt/dpsg-news/secrets/`

## iOS Xcode Cloud Variablen

Fuer `app/.env`:

- API_BASE_URL
- WIREDASH_PROJECT_ID
- WIREDASH_SECRET
- LOG_MAX_DAYS
- LOG_MAX_SIZE_MB

## Betriebsmodus

- Aktuell: Direct Push auf `main` erlaubt
- Geplant spaeter: Push auf `main` verhindern und PR-only aktivieren
