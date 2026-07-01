# App Store Connect und Xcode Cloud Vorbereitung

## Ziel

Diese App ist jetzt für die Integration mit App Store Connect und Xcode Cloud vorbereitet. Die wichtigsten Schritte sind:

1. App in App Store Connect anlegen.
2. Bundle Identifier sicherstellen.
3. Signierung und Berechtigungen in Xcode hinterlegen.
4. Xcode Cloud-Pipeline mit dem iOS-Target verbinden.

## Wichtige Werte

- Bundle Identifier: de.jlange.dpsgnews
- Team: 6WMJR3R823
- iOS Deployment Target: 13.0
- Flutter Build-Nummer: wird über die Build-Umgebung gesetzt.

## Xcode Cloud

- Das Skript in ios/ci_scripts/ci_post_clone.sh installiert Flutter, fuehrt `flutter pub get` aus und macht `pod install`.
- Das Skript in ios/ci_scripts/ci_pre_xcodebuild.sh erstellt `app/.env` auf Basis von `app/.env.example` und uebernimmt gesetzte Xcode-Cloud-Variablen.
- Das Skript in ios/ci_scripts/ci_post_xcodebuild.sh gibt Build-Artefakt-Hinweise aus.

### Xcode-Cloud-Variablen fuer app/.env

Die folgenden optionalen Variablen werden aus Xcode Cloud in `app/.env` geschrieben, wenn sie gesetzt sind:

- `API_BASE_URL`
- `WIREDASH_PROJECT_ID`
- `WIREDASH_SECRET`
- `LOG_MAX_DAYS`
- `LOG_MAX_SIZE_MB`

## Nächste Schritte in App Store Connect

- Neue App anlegen.
- Bundle Identifier mit de.jlange.dpsgnews verknüpfen.
- Signierung mit dem passenden Apple-Developer-Team konfigurieren.
- Erste Version und Build in App Store Connect hochladen.

## Hinweise

- Die App sollte lokal mit `flutter build ios --release` geprüft werden.
- Für Xcode Cloud ist eine funktionierende Apple Developer Signierung erforderlich.
