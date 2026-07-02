# App

Flutter-Frontend für die DPSG News APP.

## Voraussetzungen

- Flutter SDK installiert

## Einrichtung

```bash
cd app
flutter pub get
```

## Start

```bash
flutter run
```

## Flavors (iOS Firebase)

- `ios/firebase/dev/GoogleService-Info.plist` wird fuer `dev` verwendet.
- `ios/firebase/prod/GoogleService-Info.plist` wird fuer `prod` verwendet.
- Die Auswahl erfolgt in Xcode ueber die Schemes `dev` und `prod` bzw. ueber Flutter-Flavors.

Beispiele:

```bash
flutter run --flavor dev -t lib/main.dart
flutter run --flavor prod -t lib/main.dart
```

## Test

```bash
flutter test
```

## Konfiguration

- Die App laedt standardmaessig `app/.env.example` aus dem Asset-Bundle.
- Lokale bzw. CI-spezifische Werte sollten ueber Build-Umgebung bzw. `--dart-define` gesetzt werden.
- Es gibt keine globale Root-Env mehr; App und Server werden getrennt konfiguriert.
