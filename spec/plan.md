# DPSG Events App – Konzept

## Vision

Eine schlanke App, die Pfadfinderinnen und Pfadfinder über kommende Veranstaltungen informiert.

Die App soll **keine Eventverwaltung**, sondern ein **Informationsportal für Veranstaltungen** sein.

Schwerpunkte:

- Kommende Veranstaltungen entdecken
- Schnell alle wichtigen Informationen erhalten
- Direkt zur Anmeldung gelangen
- Push-Benachrichtigungen für relevante Veranstaltungen

Nicht Bestandteil:

- Nutzerkonten für Teilnehmer
- Anmeldung innerhalb der App
- Kommentare
- Chats
- Bildergalerien
- Social Features

---

# Zielgruppe

- Interessierte Mitglieder
- Leitende
- Rover
- Bezirke
- Diözesanverbände

---

# Benutzerrollen

## Anonymer Nutzer

Kein Login erforderlich.

Kann:

- Veranstaltungen ansehen
- Veranstaltungen durchsuchen
- Nach Kategorien filtern
- Push-Benachrichtigungen erhalten
- Veranstaltungen merken
- Veranstaltungen in den Kalender übernehmen

Lokale Einstellungen:

- ausgewählter DV
- ausgewählte Kategorien
- Push aktiviert/deaktiviert
- gemerkte Veranstaltungen

---

## Autor

Login erforderlich.

Kann:

- Veranstaltungen erstellen
- bearbeiten
- veröffentlichen
- archivieren
- löschen

Ein Autor gehört genau zu einem DV.

Er darf ausschließlich Veranstaltungen seines eigenen DVs verwalten.

---

## Administrator

Optional für spätere Version.

Kann:

- Autoren verwalten
- Rollen vergeben

---

# MVP-Funktionen

## Eventliste

Anzeige aller zukünftigen Veranstaltungen.

Sortierung:

- nach Startdatum aufsteigend

Jeder Eintrag zeigt:

- Titel
- Datum
- Ort
- Kurzbeschreibung

---

## Eventdetails

Anzeige von:

- Titel
- Beschreibung (Markdown)
- Startdatum
- Enddatum
- Ort
- Veranstalter
- Kategorien
- DV
- Anmeldeschluss
- Link zur Anmeldung
- Link zu weiteren Informationen

Aktionen:

- Zur Anmeldung
- Weitere Informationen
- Zum Kalender hinzufügen
- Merken

---

## Suche

Lokale Volltextsuche in bereits geladenen Veranstaltungen.

Suche in:

- Titel
- Beschreibung
- Ort
- Veranstalter

---

## Filter

Filter nach:

- Kategorien
- Zeitraum (optional später)

---

## Einstellungen

Der Nutzer wählt:

### Diözesanverband

z.B.

- Hamburg
- Köln
- Münster
- ...

### Kategorien

Mehrfachauswahl.

Beispiele:

- Allgemein
- Wölflinge
- Jungpfadfinder
- Pfadfinder
- Rover
- Leitende
- Ausbildung
- International
- Spiritualität

Diese Auswahl bestimmt:

- sichtbare Veranstaltungen
- Push-Benachrichtigungen

---

# Autorenbereich

Direkt in der Flutter-App integriert.

Login per E-Mail und Passwort.

Bereiche:

- Meine Veranstaltungen
- Neue Veranstaltung
- Entwürfe
- Veröffentlichte Veranstaltungen

---

# Eventmodell

## Pflichtfelder

- Titel
- Startdatum
- mindestens eine Kategorie
- DV

## Optionale Felder

- Enddatum
- Ort
- Beschreibung
- Veranstalter
- Anmeldeschluss
- Link zur Anmeldung
- Link zu weiteren Informationen

---

# Datenmodell

## Event

```text
id

title
description (Markdown)

startDate
endDate

location

organizer

registrationDeadline

registrationUrl
infoUrl

categories[]

dv

status

authorId

createdAt
updatedAt
publishedAt
```

---

## Author

```text
id

name
email
passwordHash

role

dv

active
```

---

## Kategorie

```text
id

key
name
```

---

## DV

```text
id

key
name
```

---

# Eventstatus

```text
DRAFT
PUBLISHED
ARCHIVED
```

Veröffentlichungsablauf:

```text
DRAFT
      │
      ▼
PUBLISHED
      │
      ▼
ARCHIVED
```

Archivierung erfolgt automatisch.

Regeln:

Wenn Enddatum vorhanden:

- archivieren nach Enddatum

Wenn kein Enddatum vorhanden:

- archivieren nach Startdatum

---

# Rechte

Ein Autor gehört genau einem DV.

Ein Autor darf:

- Veranstaltungen erstellen
- Veranstaltungen bearbeiten
- veröffentlichen
- löschen
- archivieren

Es gibt keine Moderation.

Änderungen an veröffentlichten Veranstaltungen werden direkt gespeichert.

Standardmäßig wird **keine weitere Push-Benachrichtigung** versendet.

Später kann optional eine Funktion ergänzt werden:

> "Nutzer über Änderung informieren"

---

# Push-Konzept

Firebase Cloud Messaging (FCM)

Beim ersten Start wählt der Nutzer:

- DV
- Kategorien

Beispiel:

DV:

```
Hamburg
```

Kategorien:

```
Rover
Leitende
```

Die App subscribed automatisch auf passende Topics.

Beispielsweise:

```
events.hamburg.rover

events.hamburg.leitende
```

---

## Veröffentlichung

Autor veröffentlicht Veranstaltung.

Backend:

1. speichert Event
2. setzt Status auf PUBLISHED
3. sendet Push an passende Topics

Beispiel:

Event:

```
DV Hamburg

Kategorien:

Rover
Leitende
```

Push an:

```
events.hamburg.rover

events.hamburg.leitende
```

Ein Nutzer erhält eine Push, wenn **mindestens eine seiner Kategorien** übereinstimmt.

---

## Push-Inhalt

Push enthält nur:

```json
{
  "title": "Rover-Wochenende",
  "body": "Jetzt anmelden!",
  "data": {
    "eventId": 123
  }
}
```

Beim Öffnen:

```
GET /api/events/{id}
```

Dadurch werden immer aktuelle Daten geladen.

---

# Offline

Beim Start:

- zunächst lokale Daten anzeigen
- anschließend Server synchronisieren
- lokale Daten aktualisieren

Dadurch funktioniert die App auch ohne Internet.

---

# Kalender

Export in den Systemkalender.

Übertragene Informationen:

- Titel
- Startdatum
- Enddatum
- Ort
- Beschreibung
- Veranstalter
- Anmeldelink
- Link zu weiteren Informationen
- Kategorien
- DV

---

# Links

Maximal zwei Links:

```text
registrationUrl

infoUrl
```

---

# Tech Stack

## Frontend

Flutter

Eine App für:

- Nutzer
- Autoren

---

## Backend

Spring Boot

- REST API
- Spring Security
- JWT Auth
- Firebase Admin SDK

---

## Datenbank

PostgreSQL

---

## Push

Firebase Cloud Messaging

Topic-basierte Push-Benachrichtigungen.

---

# API

## Öffentlich

```
GET /api/events

GET /api/events/{id}

GET /api/events/{id}/calendar
```

---

## Auth

```
POST /api/login

POST /api/logout

POST /api/refresh
```

---

## Autoren

```
POST /api/events

PUT /api/events/{id}

DELETE /api/events/{id}

POST /api/events/{id}/publish
```

---

# Deployment

Docker Compose

```text
nginx
spring-boot
postgres
```

Alle Container laufen zunächst auf einer einzelnen VM.

---

# Infrastruktur

## Phase 1

Eine kleine VM.

Geeignete Anbieter:

- Hetzner Cloud
- Netcup VPS
- IONOS VPS

Kosten:

ca. 4–8 €/Monat

Enthalten:

- Spring Boot
- PostgreSQL
- Nginx

---

## Phase 2

Mehr Nutzer.

Aufteilung:

Server 1

- Spring Boot

Server 2

- PostgreSQL

---

## Phase 3

Weitere Skalierung.

Optional:

- mehrere Spring Boot Instanzen
- Load Balancer
- Managed PostgreSQL
- Redis

---

# Betriebskosten

## 1.000 Nutzer

Server:

ca. 4–8 €/Monat

Firebase Push:

kostenlos

Apple Developer:

99 USD/Jahr

Google Play:

25 USD einmalig

---

# Mögliche Erweiterungen

- Favoriten synchronisieren
- Änderungsbenachrichtigungen
- Event-Erinnerungen
- Bezirksveranstaltungen
- Veranstaltungsserien
- Mehrsprachigkeit
- PDF-Anhänge
- Deep Links
- Webansicht einzelner Veranstaltungen
- Rollenverwaltung
- Import bestehender Veranstaltungen
- Statistiken

---

# Leitprinzipien

- Kein Login für normale Nutzer
- Eine App für Nutzer und Autoren
- Minimaler Serveraufwand
- Geringe Betriebskosten
- Datenschutzfreundlich
- Offlinefähig
- Einfache Bedienung
- Einfache Skalierbarkeit
- Fokus auf Veranstaltungen
- Keine unnötigen Features