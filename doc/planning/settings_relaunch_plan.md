# Plan: Umbau der Einstellungen nach NamiApp-Vorbild

## Zielbild

Die Einstellungen sollen in der DPSG-News-App künftig wie in der Nami-App aufgebaut sein, aber bewusst auf die Bedürfnisse der aktuellen App reduziert werden.

### Geplante Struktur

- Oberer Profilbereich
  - Standard: „Anonym“
  - späterer Login-Mechanismus als erweiterbarer Punkt
  - Autor-Modus als Teil des Profil-/Entwicklungsbereichs
- Kein Bereich „Schnellzugriff“
- Hauptbereich „Einstellungen“ mit mehreren Unterpunkten:
  - App-Einstellungen
  - Benachrichtigungseinstellungen
  - Debug & Tools
  - Impressum
  - Datenschutz
  - Footer: „Entwickelt mit Herz in Hamburg“

## Aktueller Stand in der Ziel-App

Die bestehende App hat bereits eine einfache Einstellungsseite mit:

- DV-Auswahl
- API-URL
- API-Status
- APNS-Token
- Autor-Modus

Das ist funktional gut, aber noch nicht in die geplante Struktur mit eigenen Unterseiten und neuen Funktionen überführt.

## Befund nach abgebrochenem Durchgang

Der letzte Durchgang wurde nicht durch einen einzelnen Blocker beendet, sondern durch instabile Validierung:

- Widget-Tests liefen teils erfolgreich, teils mit Timeouts (`pumpAndSettle`) oder nicht gefundenen Texten
- `flutter analyze` lieferte in den Log-Auszügen zeitweise wechselnde Ergebnisse
- dadurch entstand ein Wiederholungs-Loop ohne klare Abarbeitungsreihenfolge

Offen vor dem nächsten Implementierungsschritt:

- Teststabilisierung für Settings-Navigation und Benachrichtigungsseite
- einmalige, reproduzierbare Validierungssequenz statt Mehrfach-Loop
- inhaltliche Anpassung der Benachrichtigungstexte und -logik gemäß untenstehender Spezifikation

## Übernommene Bausteine aus der Nami-App

Die Referenz-App liefert besonders gute Vorbilder für:

- Profil-Card oben im Settings-Bereich
- klare Untersektionen für Einstellungen
- separate Seiten für Rechts-/Entwicklungsbereiche
- Footer mit Versionshinweis und Herz-Icon

## Vorgehen in kleinen Schritten

### Phase 1 – Struktur vorbereiten

Ziel: Die bestehende Einstellungsansicht in ein klareres Navigationsmodell überführen.

- Die aktuelle Settings-Seite als Startpunkt behalten
- Neue Unterseiten anlegen für:
  - App-Einstellungen
  - Benachrichtigungseinstellungen
  - Debug & Tools
  - Impressum
  - Datenschutz
- Die bestehende Einstellungsseite als Übersicht mit Navigationselementen aufbauen
- Profilbereich oben ergänzen
- Die Übersicht soll sich optisch an der Nami-App orientieren: Kartenlayout, klare Section-Header, ruhige Farben, einheitliche Icons und abgesetzte Reihen

Ergebnis: Die Nutzer sehen direkt eine moderne, strukturierte Einstellungen-Übersicht.

### Phase 2 – Profilbereich und Einstieg

Ziel: Den oberen Bereich der Settings-Ansicht an das NamiApp-Muster anlehnen.

- Profil-Card einbauen
- Standardwert: „Anonym“
- Dummy Form: „Login später verfügbar“
- DV-Auswahl als Bereich im Profilbereich behandeln
- Autor-Modus direkt im Profilbereich platzieren oder als klarer, kleiner Entwickler-/Support-Bereich dort sichtbar machen
- Der Profilbereich soll bewusst schlicht bleiben und für späteren Login-Mechanismus offen sein

Ergebnis: Der Einstieg wirkt sauberer und ist zukunftssicher für Login-Features.

### Phase 3 – App-Einstellungen

Ziel: Eine neue Kategorie für grundlegende App-Optionen schaffen.

Inhaltlich minimal und sinnvoll umgesetzt:

- Darstellung
  - Dark Mode
- Nutzeranalyse / Tracking
  - Optionaler Toggle für Nutzungs-/Analyse-Tracking
  - Wiredash-Opt-in
- Weitere App-Optionen nach Bedarf
  - z. B. API-/Entwickler-Optionen, falls sinnvoll

Ergebnis: Die App bekommt ein eigenes, verständliches „App-Einstellungen“-Menü.

### Phase 4 – Benachrichtigungseinstellungen

Ziel: Bestehende Funktionalität sauber als eigene Kategorie sichtbar machen.

- Globaler Schalter als erster Eintrag: „Benachrichtigungen aktiv“
- Wenn „Benachrichtigungen aktiv“ umgelegt wird (aus oder wieder ein):
  - Benachrichtigungswerte werden auf Standard zurückgesetzt
  - Standardwerte:
    - „Erinnerung vor Anmeldeschluss“ = 2 Tage vorher
    - „Erinnerung für zugesagte Veranstaltungen“ = 1 Tag vorher
  - alle abhängigen Einzeloptionen folgen diesen Standardwerten
- Einzeloptionen mit nutzernaher Sprache:
  - „Neue Veranstaltungen“
  - „Erinnerung für zugesagte Veranstaltungen“
  - „Erinnerung vor Anmeldeschluss“
  - „Wochenübersicht“
- Eigene Auswahl „Tage vorher“ je Erinnerung:
  - für „Erinnerung für zugesagte Veranstaltungen“: 1 bis 10
  - für „Erinnerung vor Anmeldeschluss“: 1 bis 10
- „Wochenübersicht“ wird lokal auf dem Gerät erstellt (keine Firebase-Formulierung in der UI)
- DV-/Themen-Auswahl bleibt als eigener, klarer Einstiegspunkt innerhalb der Seite erhalten

Ergebnis: Nutzer finden ihre Benachrichtigungspräferenzen direkt an einem Ort.

### Textvorschläge für Benachrichtigungsseite

Ziel: Keine Technikbegriffe wie „Firebase“, keine uneinheitlichen Begriffe wie „Push“/„Reminder“.

Hinweis: Texte wurden bereits angepasst und werden nicht erneut überschrieben. Für den aktuellen Schritt ist nur die Wochenübersicht als Option mit passender Menüformulierung relevant.

- Seitentitel: „Benachrichtigungen“
- Hauptschalter:
  - Titel: „Benachrichtigungen aktiv“
  - Untertitel: Schalte alle Benachrichtigungen dieser App ein/aus“ (ein/aus je nach aktuellem zustand)
- Einzeloptionen:
  - „Neue Veranstaltungen“
    - Untertitel: „Benachrichtigungen zu neu veröffentlichten Veranstaltungen“
  - „Erinnerung für zugesagte Veranstaltungen“
    - Untertitel: „Hinweis auf Veranstaltungen, denen du zugesagt hast“
    - Zusatzfeld: „Tage vorher“
  - „Erinnerung vor Anmeldeschluss“
    - Untertitel: „Hinweis vor dem Ende der Anmeldefrist“
    - Zusatzfeld: „Tage vorher“
  - „Wochenübersicht“
    - Untertitel: „Wöchentliche Zusammenfassung deiner relevanten Termine“
- DV-/Themen-Bereich:
  - Titel: „Interessen anpassen“
  - Untertitel: „Diözesen und Themen auswählen“
  - Button: „Auswählen“

### Phase 5 – Debug & Tools

Ziel: Eine Entwickler- und Support-Orientierte Kategorie ergänzen.

Inhalte:

- API-URL
- API-Status
- APNS-Token
- App Logs
  - App-Logs
  - Request-Logs
- DV-Tree aktualisieren
- Feedback und Bewertung
- Changelog
- Externe Benachrichtigungen

Verbindliche Vorgaben fuer den naechsten Block:

- Debug & Tools wird als eigene Seite umgesetzt (kein Inline-Bereich mehr in der Settings-Uebersicht)
- Vorhandene Elemente werden auf diese Seite uebernommen:
  - API-URL
  - API-Status
  - APNS-Token
- NamiApp als Referenz fuer Design und Funktion:
  - Referenzpfad: /Users/lange/Documents/namiapp/dpsg-nami-app
  - Ziel: visuell und funktional so nah wie moeglich an der NamiApp
  - Reihenfolge der Menuepunkte ist dabei nachrangig
- Inhaltliche Muss-Punkte fuer diese App:
  - App Logs
    - App-Logs
    - Request-Logs
  - Feedback und Bewertung wie in NamiApp
    - Feedback-Ausloeser
    - Bewertungs-Ausloeser
  - Changelog
  - Externe Benachrichtigungen als Platzhalterseite

Hinweis: Die Funktionalität kann zunächst simpel aufgebaut werden, z. B. mit Platzhaltern oder einer ersten, reduzierten Version.

Ergebnis: Support, Testing und Weiterentwicklung werden deutlich einfacher.

#### Phase-5 Umsetzungsstrategie (NamiApp-Paritaet)

Ziel fuer diesen Block: Aufbau und Reihenfolge identisch zum NamiApp-Muster.

Reihenfolge fuer die Umsetzung:

1. UI zuerst bauen
  - Eintraege sichtbar und navigierbar anlegen:
    - App Logs
     - App-Logs
     - Request-Logs
    - Feedback und Bewertung
    - Changelog
    - Externe Benachrichtigungen (zunaechst Platzhalter)
  - Zunaechst ohne tiefe Fachlogik, aber mit stabiler Navigation und klaren Titeln
2. Features danach umsetzen
  - Changelog-Funktion
  - Feedback- und Bewertungs-Funktion wie in NamiApp
  - Log-Funktionen (App-Logs und Request-Logs)
3. Features an UI anbinden
  - Platzhalterseiten schrittweise durch funktionale Seiten ersetzen
  - keine harten Brueche in Navigation oder Bezeichnern

Abnahmekriterien fuer „identisch zu NamiApp“ in Phase 5:

- gleiche Informationsarchitektur (gleiche Punktreihenfolge und Gruppierung)
- gleiche Einstiegspunkte (jede Funktion als eigener klarer Menuepunkt)
- keine versteckten Entwickleraktionen; alles direkt ueber Debug & Tools erreichbar
- fuer jeden Menuepunkt existiert mindestens eine stabile Zielseite (Platzhalter oder Featureseite)

### Phase 6 – Rechtliches und Footer

Ziel: Die rechtlichen Bereiche und den unteren Abschluss sauber ergänzen.

- Impressum
- Datenschutz
- Footer mit:
  - „Entwickelt mit Herz in Hamburg“
  - Versionshinweis

Ergebnis: Die Seite wirkt abgeschlossen und professionell.

## Neue Funktionen im Detail

### Lokalisierung und Sprache

- Alle Nutzer-Strings sollen bereits als Translation-Variablen angelegt werden
- Die erste verfügbare Option in den Einstellungen soll die Sprache sein
- Für die erste Version nur Deutsch anbieten
- Die UI soll bereits so aufgebaut sein, dass spätere Sprachen einfach ergänzt werden können

### Dark Mode

- Minimal implementieren, aber sauber über eine zentrale Theme-Logik
- Optional als systemabhängig oder explizit einstellbar

### Wiredash

- Als späterer, klar abgegrenzter Bereich innerhalb der App-Einstellungen oder Debug-&-Tools
- Minimaler Einstieg: Feedback-Button und Opt-in/Opt-out

#### Wiredash-Plan (Einbau + Anbindung)

Ziel: Wiredash sauber integrieren und an bestehende Strukturen koppeln:

- Logging ueber vorhandenen LoggingService
- Opt-in ueber bestehenden Toggle „Nutzungs-/Analyse-Tracking"
- Feedback-Start ueber vorhandenen Button in Debug & Tools

Finale Entscheidungen fuer diesen Planstand:

- Keys und Secret kommen ausschliesslich ueber Env-Konfiguration
- keine Trennung der Wiredash-Keynamen zwischen `dev` und `prod` in der App
- die Umgebung steuert die konkreten Werte ausserhalb der App-Konfiguration
- Der Toggle „Nutzungs-/Analyse-Tracking“ steuert nur Event-Tracking
- Bewertung/Store-Weiterleitung wird auf spaeter verschoben (Store-Ziel noch offen)

Technischer Plan:

1. Konfiguration und Secrets
  - neue Env-Keys definieren:
     - `WIREDASH_PROJECT_ID`
     - `WIREDASH_SECRET`
   - lokales `app/.env` bekommt konkrete Werte (nicht committen)
   - `app/.env.example` enthaelt nur Schluessel/Platzhalter, kein Secret
2. App-Initialisierung
  - Wiredash als Wrapper oberhalb von `MaterialApp` integrieren
  - Projekt-ID und Secret aus zentraler Konfiguration laden
3. Opt-in-Anbindung
  - bestehender Toggle `analyticsTracking` bleibt Single Source of Truth
  - bei `false`: keine Wiredash-Event-Tracking-Events senden
  - bei `true`: Wiredash-Event-Tracking aktivieren
  - Feedback-Dialog bleibt davon unberuehrt nutzbar
4. Logger-Anbindung
  - LoggingService erweitert um optionales Forwarding an Wiredash
  - Events weiter lokal loggen, zusaetzlich (bei Opt-in) an Wiredash senden
  - Fehlerereignisse (`logError`) als priorisierte Telemetrie markieren
5. Feedback-Button-Anbindung
  - aktueller Platzhalter in Debug & Tools wird auf Wiredash-Feedbackdialog umgestellt
  - Bewertungsaktion bleibt vorerst Platzhalter bis die Store-Seite feststeht
6. Validierung
  - Widget-Test: Feedback-Button triggert Wiredash-Action (ueber Mock/Adapter)
  - Unit-Test: Opt-in steuert Forwarding korrekt (an/aus)
  - `flutter analyze` + `flutter test`

Sicherheits- und Release-Regeln:

- Secret nie in Commit, nie in `.env.example`, nie in Doku mit Klarwert
- fuer CI/Build-Pipelines nur Secret-Store verwenden
- bei Secret-Rotation nur Build-/Env-Konfiguration anpassen, nicht App-Logik

Konkrete Werte fuer lokale `app/.env` (wie besprochen):

- `WIREDASH_PROJECT_ID` = bereitgestellt
- `WIREDASH_SECRET` = bereitgestellt

Hinweis: Die Klarwerte werden bewusst nicht in dieser Plan-Datei abgelegt.

### App Logs

- Zielbild: Nami-Logik fuer Erfassung, Speicherung, Anzeige und Bereinigung in DPSG News uebernehmen.

#### Logging-Scope (neu)

- User-Interaktionen vollstaendig loggen:
  - Menue-Openings, Tile-Taps, Buttons, Toggle-Changes, Dialog-Aktionen
  - Back-Navigation (System-Back, AppBar-Back, Route-Pop)
  - zentrale Flows (Settings-Flow, Notification-Flow, Feedback-Flow)
- App-Flow/Lifecycle loggen:
  - `app_started`, `app_resumed`, `app_paused`, `app_hidden`, `app_detached`
  - Session-Nutzungszeit als `session_duration seconds=<n>`
- Request-Logging ausbauen:
  - Request wurde ausgefuehrt (nur Metadaten: `source`, `method`, `url`, Dauer)
  - keine Auth-Daten und keine sensitiven Header loggen
  - Ergebnis (`status`, Fehlerklasse, Dauer)
  - bei Fehlern zusaetzlich Response-Body (falls vorhanden) und kurze Fehlerzusammenfassung

#### Nami-Referenz, die uebernommen wird

- Einheitliches Log-Format je Zeile mit Zeit, Level und Service:
  - `[yyyy-MM-dd HH:mm:ss] [level] [service] message`
- Service-Domaenen wie in Nami:
  - `ui`, `nav`, `lifecycle`, `usage`, `http`, `settings`, `debug_tools`
- Event-Benennung wie in Nami beibehalten (kein neues separates Namensschema einfuehren).
- Navigationslogging ueber `NavigatorObserver` (Push/Pop).
- Lifecycle + Nutzungszeit analog `UsageTrackingService`:
  - Session bei App-Start
  - Pause/Resume mit Schwellwert fuer Session-Neustart
  - persistenter Pause-Snapshot fuer robuste Dauerberechnung

#### Speicher- und Loeschstrategie (aus Nami uebernehmen)

- Tagesdateien fuer App-Logs (`app-YYYY-MM-DD.log`).
- Bereinigung nach zwei Grenzen:
  - Alter: `LOG_MAX_DAYS` (Default 7 Tage)
  - Groesse: `LOG_MAX_SIZE_MB` (Default 1 MB gesamt)
- Wenn Groessenlimit erreicht ist, zuerst aeltere Tage loeschen, heutige Datei bleibt erhalten.
- Request-Detail-Logs als eigene Quelle (`request`), separat loeschbar und selektierbar.

#### Debug & Tools Anforderungen fuer Logs

- Log-Quellen auswaehlbar:
  - wie in Nami als Quellen-Auswahl innerhalb eines Log-Centers
  - `App-Logs` und `Request-Logs` als zwei Quellen
- Aktionen je Quelle wie in Nami:
  - Anzeigen
  - per Mail senden (Dateianhaenge)
  - Loeschen
- Mailversand wie in Nami an feste Entwickleradresse: `dev@jannecklange.de`
- Dateiauswahl:
  - Alle Dateien
  - Einzeldatei
- Log-Viewer UX wie in Nami:
  - farbliche Kennzeichnung nach Level (`info`, `warn`, `error`, `debug`)
  - Monospace-Darstellung mit selektierbarem Text
  - Floating-Action-Button "Back to bottom"

#### Datenschutz und Robustheit

- Keine Secrets/Tokens im Klartext loggen (Authorization/Header redaction).
- Query-Parameter mit `token`/`secret` maskieren.
- Auth-Informationen grundsaetzlich nicht in Log-Payloads aufnehmen.
- Logging darf App-Flow nicht blockieren (fehlertolerant, best effort).

#### Verbindliche Entscheidungen (Stand 2026-07-01)

- Request-Logging: nur Metadaten; Response-Body nur im Fehlerfall.
- Mailversand: wie in Nami an `dev@jannecklange.de`.
- Event-Naming: wie in Nami, ohne neues eigenes Schema.
- Debug-Logs UI: Quellen- und Aktionsstruktur wie in Nami.

#### Umsetzungsreihenfolge fuer den Logging-Block

1. Logger-Grundstruktur auf Nami-Format bringen (Service + Zeit + Level).
2. Navigation- und UI-Interaktionslogging zentral einhaengen.
3. Lifecycle + Nutzungszeittracking integrieren.
4. Request-Logging mit Ergebnis/Fehlerpfad verdrahten.
5. Debug-&-Tools Log-Center (anzeigen/senden/loeschen, Quelle + Dateiauswahl).
6. Viewer-Farben und Back-to-bottom-FAB finalisieren.
7. Retention und Limits per Env-Keys aktivieren und testen.

#### Akzeptanzkriterien

- Jede relevante User-Aktion erzeugt einen Logeintrag mit Service und Zeit.
- Back-Navigation und Route-Wechsel sind nachvollziehbar.
- Session-Dauer wird bei Hintergrundwechseln korrekt persistiert und geloggt.
- Jede Request-Aktion hat mindestens einen Start- und einen Ergebnis-Logeintrag.
- Debug & Tools erlaubt Anzeigen, Mailversand und Loeschen fuer beide Log-Quellen.
- Log-Viewer zeigt Level-Farben und einen funktionierenden "Back to bottom"-Button.

### Changelog

- Einfache Changelog-Seite aus statischem Inhalt oder einfacher Datenquelle
- Später erweiterbar

## Umsetzungsempfehlung

Ich würde den Umbau in dieser Reihenfolge realisieren:

1. Struktur der Übersichtsseite
2. Profilbereich
3. Unterseiten für App-, Benachrichtigungs- und Rechtsbereiche
4. Debug & Tools
5. Neue Funktionen wie Dark Mode, Wiredash, Logs, Changelog
6. Feinschliff und QA

## Offene Fragen

- Soll der Autor-Modus direkt im Profilbereich bleiben oder als eigener, kleiner Switch im Profilbereich sichtbar sein?
- Soll der Login-Mechanismus schon als sichtbarer Placeholder eingebaut werden oder erst später?
- Soll die Spracheinstellung direkt im ersten Umsetzungsschritt sichtbar sein oder erst nach der Basisstruktur?

## Entscheide für die erste Version

- Die erste Version soll bewusst schlicht und stabil sein.
- Der Fokus liegt auf der Basisstruktur und den wirklich wichtigen Funktionen.
- Neue Funktionen wie Dark Mode, Wiredash, Logs oder Changelog sollen erst dann erweitert werden, wenn die Basis sauber funktioniert.
- Für den nächsten Umsetzungsblock gilt ein enger Scope:
  - Wochenübersicht nur als aktivierbare Option mit passender Menübeschriftung
  - andere Erweiterungen werden auf spätere Schritte verschoben

## Nächster Schritt

Als erster Umsetzungsblock würde ich die neue Settings-Übersicht mit Profilbereich und den fünf Hauptkategorien aufbauen, ohne die neuen Funktionen noch komplett zu verdrahten.
