# Xcode Cloud scripts

Diese Ordnerstruktur ist für Xcode Cloud vorbereitet:

- app/ios/ci_scripts/ci_post_clone.sh
- app/ios/ci_scripts/ci_pre_xcodebuild.sh
- app/ios/ci_scripts/ci_post_xcodebuild.sh

Xcode Cloud kann diese Skripte über die Projekt- oder Pipeline-Konfiguration aufrufen, sofern der Pfad zum iOS-Target und das Workspace korrekt gesetzt sind.
