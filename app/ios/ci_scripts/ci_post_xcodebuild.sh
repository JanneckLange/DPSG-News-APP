#!/bin/bash
set -euo pipefail

if [ -d "build/ios/iphoneos" ]; then
  echo "Archive artifacts are available in build/ios/iphoneos"
fi
