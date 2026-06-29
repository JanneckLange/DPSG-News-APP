#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ -f "pubspec.yaml" ]; then
  flutter pub get
fi

if [ -f "ios/Podfile" ]; then
  cd ios
  pod install --repo-update
fi
