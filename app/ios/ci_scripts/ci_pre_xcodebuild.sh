#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)}"
APP_ROOT="$REPO_ROOT/app"

echo "Stage: PRE-Xcode Build is activated ...."
echo "Using repository root: $REPO_ROOT"
cd "$REPO_ROOT" || exit 1

if [ -f "$APP_ROOT/.env.example" ]; then
  cp "$APP_ROOT/.env.example" "$APP_ROOT/.env"
  if [ -n "${API_BASE_URL:-}" ]; then
    printf 'API_BASE_URL=%s\n' "$API_BASE_URL" >> "$APP_ROOT/.env"
  fi
  if [ -n "${WIREDASH_PROJECT_ID:-}" ]; then
    printf 'WIREDASH_PROJECT_ID=%s\n' "$WIREDASH_PROJECT_ID" >> "$APP_ROOT/.env"
  fi
  if [ -n "${WIREDASH_SECRET:-}" ]; then
    printf 'WIREDASH_SECRET=%s\n' "$WIREDASH_SECRET" >> "$APP_ROOT/.env"
  fi
  if [ -n "${LOG_MAX_DAYS:-}" ]; then
    printf 'LOG_MAX_DAYS=%s\n' "$LOG_MAX_DAYS" >> "$APP_ROOT/.env"
  fi
  if [ -n "${LOG_MAX_SIZE_MB:-}" ]; then
    printf 'LOG_MAX_SIZE_MB=%s\n' "$LOG_MAX_SIZE_MB" >> "$APP_ROOT/.env"
  fi
  echo "Created app/.env from app/.env.example"
else
  echo "No app/.env.example found; skipping app env preparation"
fi

if [ -d "$APP_ROOT" ]; then
  echo "Flutter app root: $APP_ROOT"
else
  echo "Flutter app directory not found at $APP_ROOT"
  exit 1
fi

echo "Stage: PRE-Xcode Build is DONE ...."
