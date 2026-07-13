# Plan: PostHog-Analytics-Aufbau für die DPSG-News-App

## Zielbild

Die App soll Wiredash als Feedback-/Support-Tool behalten, aber um PostHog als Produkt- und Nutzungs-Analytics erweitern.

Geplant ist eine transparente und datenschutzfreundliche Instrumentierung für:

- Nutzersteuerung über Klicks und Interaktionen
- Seiten-/Screenwechsel
- Einstellungen und Präferenzen
- Menüs und Dialoge
- Fehler und App-Starts
- Nutzungsdauer und Sessions

## Aktueller Stand

Die Basis ist bereits vorhanden:

- Wiredash ist in der App eingebunden
- Es gibt einen bestehenden Analytics-Opt-in im Settings-Repository
- Die App hat bereits Lifecycle-/Session-Logik über den App- und Usage-Tracking-Stack
- Die aktuelle Logging-Schicht sammelt bereits Ereignisse, aber noch nicht als strukturierte Product-Analytics-Events

## Grundsatzentscheidungen

1. PostHog wird als Produkt-Analytics verwendet.
2. Wiredash bleibt für Feedback, Bugs und Support-Workflows erhalten.
3. Die Auswertung erfolgt nur für Nutzerinteraktionen, die wirklich angestoßen werden können.
4. Es werden keine sensiblen Inhalte wie Passwörter, E-Mails oder freie Texte getrackt.
5. Die bestehende Opt-in-Logik bleibt die zentrale Freigabe-Schwelle.

## Metriken und Events

### 1. App-Lifecycle

- app_started
- app_resumed
- app_backgrounded
- app_stopped
- session_started
- session_ended
- session_duration

Eigenschaften:

- app_version
- platform
- screen
- session_id
- duration_seconds

### 2. Navigation und Screens

- screen_view

Eigenschaften:

- screen
- previous_screen
- source
- tab_index

### 3. Interaktionen

- ui_click
- menu_opened
- dialog_opened
- dialog_confirmed
- dialog_cancelled

Eigenschaften:

- screen
- element
- action
- target
- location

Beispielhafte Elemente:

- Buttons
- IconButtons
- ListTiles
- Switches
- Dropdowns
- Tabs
- Menüs

### 4. Einstellungen und Präferenzen

- settings_changed

Eigenschaften:

- setting_key
- setting_group
- value_type
- value

Wichtige Bereiche:

- Analytics-Tracking-Opt-in
- Dark Mode
- Benachrichtigungseinstellungen
- Themen-/DV-Auswahl
- Autor-/Entwickler-Optionen

### 5. Fehler und Ausnahmen

- error_captured

Eigenschaften:

- error_type
- error_message
- screen
- context
- fatal

## Umsetzungsplan

### Phase 1 – Infrastruktur vorbereiten

Ziele:

- PostHog-Konfiguration sauber in die App einbinden
- zentrale Analytics-Abstraktion anlegen
- bestehende Wiredash-Integration nicht ersetzen, sondern ergänzen

Arbeitspakete:

- PostHog-Env-Variablen ergänzen und in die App-Konfiguration einlesen
- zentralen Analytics-Service anlegen, der PostHog und ggf. Wiredash kapselt
- sicherstellen, dass Events nur dann versendet werden, wenn Analytics aktiviert sind

### Phase 2 – Lifecycle und Sessions

Ziele:

- App-Starts, Pausen, Fortsetzungen und Nutzungsdauer zuverlässig erfassen

Arbeitspakete:

- Start-/Resume-/Pause-/Stop-Events an die Analytics-Schicht binden
- Session-Dauer zentral erfassen
- bestehende Usage-Tracking-Logik mit PostHog zusammenführen

### Phase 3 – Navigation und UI-Interaktionen

Ziele:

- echte Nutzersteuerung erfassen, ohne jedes Widget einzeln zu pflegen

Empfohlene Strategie:

- zentrale Wrapper für häufige UI-Aktionen bauen
- Screen-wechsel zentral über die Navigation beobachten
- Interaktionen auf Buttons, IconButtons, ListTiles, Switches und Menüs über eine gemeinsame Abstraktion erfassen

Das reduziert den Aufwand deutlich gegenüber einer vollmanualen Instrumentierung jeder einzelnen Stelle.

### Phase 4 – Einstellungen und Konfigurationsänderungen

Ziele:

- wichtige Präferenzänderungen nachvollziehbar machen

Arbeitspakete:

- Änderungen an Settings- und Notification-Optionen als strukturierte Events senden
- nur die Änderung selbst tracken, nicht die eigentlichen Inhalte
- sensible Werte vermeiden

### Phase 5 – Fehler- und Qualitätstracking

Ziele:

- Fehler schneller erkennen und priorisieren

Arbeitspakete:

- App- und Runtime-Fehler zentral an PostHog weiterleiten
- Fehler mit Screen- und Kontextinformationen versehen
- Ausnahmen von der Überwachung ausnehmen, wenn die Nutzer-Opt-in-Logik deaktiviert ist

### Phase 6 – Dashboard und PostHog-Setup

Ziele:

- auswertbare, nutzbare Dashboards im PostHog-Produkt aufbauen

Empfohlene Dashboards:

- App-Starts und aktive Nutzer
- Screen-Views und Hauptnavigationswege
- Interaktionsvolumen pro Screen und Elementgruppe
- Einstellungen-Änderungsraten
- Fehler-/Crash-Übersicht
- Session-Dauer und Engagement

Wichtig:

- Das Dashboard sollte nicht nur aus einfachen Event-Counts bestehen, sondern aus Sinnfragen wie „wo bleiben Nutzer hängen?“, „welche Funktionen werden ignoriert?“ und „welche Fehler treten häufig auf?“

## Empfehlung für die Implementierung

Die beste Lösung ist ein hybrider Ansatz:

- Zentrale Events für Lifecycle, Navigation und Fehler
- Strukturierte Wrapper für typische UI-Aktionen
- Nur gezielte, manuelle Events für besonders wichtige Flows

Dadurch bleibt der Aufwand überschaubar, aber die Abdeckung hoch.

## Offene Fragen

1. Soll Wiredash nur für Feedback bleiben oder auch für Bug-Reports im gleichen Workflow verwendet werden?
2. Sollen alle Klicks oder nur die wichtigsten Interaktionsklassen getrackt werden?
3. Welche Settings sind für die Produktanalyse wirklich wichtig und welche sollten bewusst ausgeklammert werden?
4. Soll die Event-Namensgebung möglichst simpel gehalten werden oder stärker auf Produkt- und Feature-Modelle ausgerichtet werden?

## Sofortiger nächster Schritt

Der erste technische Schritt sollte die Einführung einer zentralen Analytics-Schicht sein, gefolgt von Lifecycle- und Navigation-Events. Danach werden die UI-Interaktionen und die Settings-Änderungen ergänzt.
