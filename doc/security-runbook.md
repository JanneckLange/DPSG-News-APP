# Security Runbook

## Ziel

Dieses Runbook beschreibt den Umgang mit Secrets fuer DPSG News APP in Entwicklung, CI/CD und Betrieb.

## Geltungsbereich

- Flutter-App Build (iOS/Xcode Cloud)
- Server Build/Deploy (GitHub Actions + Docker Hub + Linux Host)
- Runtime auf Linux-Server mit Docker Compose

## Secret-Klassen

- Build-Config (nicht hochkritisch): z. B. API-URLs, Feature-Flags
- Hochkritische App-Secrets: z. B. WIREDASH_SECRET
- Hochkritische Server-Secrets: DB-Credentials, Firebase Service Account, APNs Keys

## Secret-Quellen

### Xcode Cloud (iOS)

In Xcode Cloud als Umgebungsvariablen setzen:

- API_BASE_URL
- WIREDASH_PROJECT_ID
- WIREDASH_SECRET
- LOG_MAX_DAYS
- LOG_MAX_SIZE_MB

Uebernahme in `app/.env` erfolgt durch `app/ios/ci_scripts/ci_pre_xcodebuild.sh`.

### GitHub Actions (Server Build/Deploy)

In GitHub Repository Secrets setzen:

- DOCKERHUB_TOKEN
- SSH_HOST
- SSH_USER
- SSH_PRIVATE_KEY
- SSH_PORT

Diese Secrets sind nur fuer Build/Push/SSH-Deploy.

Das Docker-Hub-Repository ist fest auf `sapza/dpsgnews` gesetzt.

### Linux Host (Server Runtime)

Nicht in GitHub speichern:

- DB runtime secrets
- Firebase service account JSON
- APNs private keys

Ablage auf dem Host:

- /opt/dpsg-news/.env
- /opt/dpsg-news/secrets/*

Dateirechte:

- `chmod 600 /opt/dpsg-news/.env`
- `chmod 600 /opt/dpsg-news/secrets/*`
- Eigentumer: root oder dedizierter Deploy-User

Host-Haertung:

- Passwort-Login fuer SSH deaktivieren (`PasswordAuthentication no`)
- Root-Login deaktivieren (`PermitRootLogin no`)
- Nur Ports 22, 80, 443 per Firewall freigeben

## Rotation

- Sofort bei Verdacht auf Leak
- Regelmaessig mindestens alle 90 Tage fuer hochkritische Secrets
- Nach Teamwechsel oder Infrastrukturaenderungen

## Incident-Ablauf bei Secret-Leak

1. Secret sofort invalidieren/rotieren.
2. Betroffene Systeme neu provisionieren oder Sessions/Token widerrufen.
3. Git-Historie bereinigen, falls Secret committed wurde.
4. Monitoring/Logs auf Missbrauch pruefen.
5. Postmortem mit Fix-Massnahmen dokumentieren.

## Runtime-Prinzipien

- Secrets niemals in Docker Image einbauen.
- Secrets niemals in Logs ausgeben.
- Nur read-only Mounts fuer Secret-Dateien verwenden.
- Env-Dateien nicht im Repo versionieren.

## Review-Checkliste je Release

- Sind alle Secrets ausserhalb des Repos?
- Sind Runtime-Secrets nur auf dem Zielhost vorhanden?
- Sind CI-Secrets minimal und zweckgebunden?
- Ist Rotationstermin dokumentiert?
