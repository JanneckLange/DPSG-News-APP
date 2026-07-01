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

## Ohne CI

Dieses Setup enthält noch keine CI-Konfiguration. Der Fokus liegt auf einer lokal startbaren Basisstruktur.
