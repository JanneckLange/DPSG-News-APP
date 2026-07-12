#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

if [ ! -f .env.test ]; then
  echo ".env.test not found — copy .env.test.example to .env.test and adjust settings" >&2
  exit 1
fi

echo "Starting test stack using docker-compose.test.yml..."
docker compose -f docker-compose.test.yml up --build -d

TEST_PORT=${TEST_SERVER_PORT:-4001}
HEALTH_URL="http://localhost:${TEST_PORT}/__test/health"

echo "Waiting for server health at ${HEALTH_URL} (timeout 60s)"
SECS=0
until curl -fsS "$HEALTH_URL" >/dev/null 2>&1; do
  sleep 1
  SECS=$((SECS+1))
  if [ $SECS -ge 60 ]; then
    echo "Timed out waiting for test server to become healthy" >&2
    docker compose -f docker-compose.test.yml logs --no-color server || true
    exit 1
  fi
done

echo "Test server is healthy"
