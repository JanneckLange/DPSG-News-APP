# DPSG News APP

Ein monorepo mit einem Flutter-Frontend unter `app/` und einem Express-Backend unter `server/`.

## Ziel

Eine neutrale Basisstruktur ohne fachliche Event-Logik, die ein erstes startbares Setup für App und Server bereitstellt.

## Struktur

- `app/` – Flutter-Anwendung mit minimalem Startpunkt
- `server/` – Express-API mit Gesundheits- und Beispielendpunkt
- `doc/` – Projekt- und Architektur-Dokumentation
- `spec/` – technische Spezifikation und Schnittstellenplanung

## Setup

### App

```bash
cd app
flutter pub get
flutter run
```

### Server

```bash
cd server
npm install
npm start
```

## Konfiguration

- `app/.env.example` zeigt die App-spezifische lokale Konfiguration
- `server/.env.example` zeigt Backend-spezifische Umgebungsvariablen

## CI/CD

Das Repository nutzt getrennte Automatisierung:

- iOS-Builds laufen in Xcode Cloud mit den Skripten unter `app/ios/ci_scripts`.
- GitHub Actions pruefen Qualitaet fuer App und Server (Analyze/Lint/Tests/Coverage) als Warnungen.
- GitHub Actions bauen und deployen den Server bei jedem Push auf `main` per Docker Hub + SSH.

Hinweis: Android-Pipeline wird spaeter ergaenzt.

## Workflow

Für dieses Projekt wird **Claude Code** als primärer KI-Entwicklungsassistent verwendet.
Für jede neue Aufgabe oder jedes neue Feature sollte ein eigener Claude-Worktree verwendet werden.

```text
claude --worktree <feature-name> --name <feature-name>

↓
/investigate <Feature umfangreich beschreiben>

↓
Plan bestätigen

↓
Implementieren

↓
/verify-feature

↓
Manuell testen

↓
/flutter-review (optional)

/backend-review (optional)

↓
Abnahme

↓
/publish-feature
```

### 0. Worktree anlegen

Bestehende Worktrees auflisten

```bash
git worktree list
```

Bestehenden Worktree öffnen

```bash
cd .claude/worktrees/profil-bearbeiten

claude
```

start any session and say 'caveman mode', or run /caveman in Claude Code
measure what caveman save you: run /caveman-stats (numbers are estimates)

### 1. Neues Feature starten

```bash
claude --worktree feat-92 --name feat-92
```

Dadurch wird automatisch ein neuer Git-Worktree mit einem eigenen Feature-Branch erstellt. So bleiben Features sauber voneinander getrennt und `main` wird niemals direkt bearbeitet.

### 2. Aufgabe analysieren

Vor der Implementierung empfiehlt sich zunächst eine Analyse:

```text
/investigate <Feature beschreibung>
```

Der Skill:

- analysiert die relevanten Dateien
- erklärt die bestehende Implementierung
- nennt die voraussichtlich betroffenen Dateien
- schlägt mögliche Lösungswege vor
- benennt Risiken und offene Fragen

Dabei wird **kein Code verändert**.

### 3. Implementierung

Nach Freigabe der Planung erfolgt die Umsetzung in kleinen, abgeschlossenen Schritten.

Grundsätze:

- eine Aufgabe pro Session
- kleine, fokussierte Änderungen
- bestehende Architektur beibehalten
- keine unnötigen Refactorings
- Ursachen beheben statt Workarounds einzubauen

Claude erstellt bei abgeschlossenen Arbeitsschritten automatisch lokale Checkpoint-Commits.

### 4. Feature überprüfen

Vor dem eigenen Test oder einem Pull Request:

```text
/verify-feature
```

Dabei werden unter anderem geprüft:

- geänderte Dateien
- Codequalität
- Flutter Analyze
- TypeScript Typecheck
- relevante Tests
- API-Kompatibilität
- Error Handling
- Loading-, Empty- und Error-States
- Accessibility
- Sicherheitsaspekte

### 5. Optionales Review

Flutter:

```text
/flutter-review
```

Prüft beispielsweise:

- Widget-Struktur
- State Management
- UX
- Accessibility
- Performance
- Konsistenz des Designs

Backend:

```text
/backend-review
```

Prüft unter anderem:

- Security
- Validierung
- Authentifizierung
- Autorisierung
- Logging
- API-Design
- Fehlerbehandlung

### 6. Pull Request veröffentlichen

Nach erfolgreichem Test:

```text
/publish-feature
```

Dieser Skill:

- führt die Abschlussprüfung durch
- erstellt bei Bedarf einen letzten Commit
- pusht den Feature-Branch
- erstellt einen GitHub Pull Request gegen `main`
Ein Pull Request wird **niemals automatisch gemergt**.

### 7. Worktree aufräumen

Nach dem Merge kannst du den Worktree entfernen:

```bash
git worktree remove .claude/worktrees/profile
```

und anschließend den Branch löschen:

```bash
git branch -d feat/profile
```

## Wichtige Claude-Code-Befehle

## Allgemein

### `/clear`

Startet eine neue Unterhaltung, ohne Claude Code zu beenden.

Empfohlen nach jedem abgeschlossenen Feature.

### `/compact`

Fasst den bisherigen Gesprächsverlauf zusammen und reduziert den verwendeten Kontext. Sinnvoll bei längeren Sessions.

### `/context`

Zeigt Informationen über den aktuell verwendeten Kontext.

Hilfreich, wenn Claude ungewöhnlich viele Dateien gelesen hat.

### `/status`

Zeigt den aktuellen Status von Claude Code.

### `/doctor`

Prüft die Claude-Code-Konfiguration und hilft beim Finden möglicher Probleme.

### `/resume`

Setzt eine frühere Claude-Session fort.

## Installierte Claude Plugins

Folgende Plugins werden in diesem Projekt verwendet.

| Plugin              | Zweck                                                                                                   |
| ------------------- | ------------------------------------------------------------------------------------------------------- |
| `typescript-lsp`    | Verbessert die Navigation und Symbolsuche im TypeScript-Backend.                                        |
| `security-guidance` | Unterstützt bei der Erkennung typischer Sicherheitsprobleme.                                            |
| `code-review`       | Führt zusätzliche Code-Reviews vor dem Veröffentlichen eines Features durch.                            |
| `posthog`           | Ermöglicht den Zugriff auf PostHog (Analytics, Feature Flags und Fehler) über MCP, sofern eingerichtet. |

---

## Eigene Claude Skills

Zusätzlich stehen projektspezifische Skills zur Verfügung.

| Skill              | Beschreibung                                                                                                    |
| ------------------ | --------------------------------------------------------------------------------------------------------------- |
| `/investigate`     | Analysiert die bestehende Implementierung und erstellt einen Umsetzungsplan, ohne Code zu verändern.            |
| `/verify-feature`  | Prüft die aktuelle Implementierung auf Qualität, Tests, Sicherheit und Kompatibilität.                          |
| `/flutter-review`  | Führt ein gezieltes Review des Flutter-Codes hinsichtlich Architektur, UX, Accessibility und Performance durch. |
| `/backend-review`  | Prüft Backend-Code auf Sicherheit, API-Qualität, Wartbarkeit und Zuverlässigkeit.                               |
| `/publish-feature` | Führt die Abschlussprüfung durch, pusht den Feature-Branch und erstellt einen GitHub Pull Request.              |