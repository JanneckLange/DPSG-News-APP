#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

echo "Stopping and removing test stack..."
docker compose -f docker-compose.test.yml down --volumes --rmi local --remove-orphans

echo "Test stack torn down"
