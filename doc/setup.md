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

1. Kopiere `/.env.example` nach `.env`, falls du globale Variablen nutzen willst.
2. Backend-spezifische Variablen kopiere in `server/.env.example` oder `server/.env`.
