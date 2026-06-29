#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)}"
APP_ROOT="$REPO_ROOT/app"

echo "Stage: PRE-Xcode Build is activated ...."
echo "Using repository root: $REPO_ROOT"
cd "$REPO_ROOT" || exit 1

if [ -f .env.example ]; then
  cp .env.example .env
  if [ -n "${API_BASE_URL:-}" ]; then
    printf 'API_BASE_URL=%s\n' "$API_BASE_URL" >> .env
  fi
  echo "Created .env from .env.example"
else
  echo "No .env.example found; skipping .env preparation"
fi

if [ -d "$APP_ROOT" ]; then
  echo "Flutter app root: $APP_ROOT"
else
  echo "Flutter app directory not found at $APP_ROOT"
  exit 1
fi

echo "Stage: PRE-Xcode Build is DONE ...."
