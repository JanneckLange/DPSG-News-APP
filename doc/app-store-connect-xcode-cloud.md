# App Store Connect und Xcode Cloud Vorbereitung

## Ziel

Diese App ist jetzt für die Integration mit App Store Connect und Xcode Cloud vorbereitet. Die wichtigsten Schritte sind:

1. App in App Store Connect anlegen.
2. Bundle Identifier sicherstellen.
3. Signierung und Berechtigungen in Xcode hinterlegen.
4. Xcode Cloud-Pipeline mit dem iOS-Target verbinden.

## Wichtige Werte

- Bundle Identifier: de.jlange.dpsgnews.app
- Team: 6WMJR3R823
- iOS Deployment Target: 13.0
- Flutter Build-Nummer: wird über die Build-Umgebung gesetzt.

## Xcode Cloud

- Das Skript in ios/ci_scripts/ci_pre_xcodebuild.sh installiert Flutter-Abhängigkeiten und CocoaPods.
- Das Skript in ios/ci_scripts/ci_post_xcodebuild.sh markiert den Build-Ordner als Artefakt-Checkpoint.

## Nächste Schritte in App Store Connect

- Neue App anlegen.
- Bundle Identifier mit de.jlange.dpsgnews.app verknüpfen.
- Signierung mit dem passenden Apple-Developer-Team konfigurieren.
- Erste Version und Build in App Store Connect hochladen.

## Hinweise

- Die App sollte lokal mit `flutter build ios --release` geprüft werden.
- Für Xcode Cloud ist eine funktionierende Apple Developer Signierung erforderlich.
