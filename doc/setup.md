# Setup

## Voraussetzungen

- Flutter SDK installiert
- Node.js 18+ installiert
- npm oder pnpm verfügbar

## App starten

```bash
cd app
flutter pub get
flutter run
```

## Server starten

```bash
cd server
npm install
npm start
```

## Lokale Konfiguration

1. Kopiere `app/.env.example` nach `app/.env` fuer App-spezifische Variablen.
2. Backend-spezifische Variablen bleiben in `server/.env.example` oder `server/.env`.
