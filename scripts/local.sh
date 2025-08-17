#!/usr/bin/env bash
set -euo pipefail

# --- Resolve repo root robustly ---
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.env"

# --- docker compose wrapper (uses sudo if needed) ---
dc() {
  # Prefer running without sudo when possible
  if docker info >/dev/null 2>&1; then
    docker compose "$@"
    return
  fi
  # Fallback: try sudo
  if command -v sudo >/dev/null 2>&1; then
    sudo docker info >/dev/null 2>&1 || {
      echo "[ERROR] Docker daemon is not accessible (even with sudo). Is the service running?" >&2
      echo "        Try: sudo systemctl enable --now docker" >&2
      exit 1
    }
    sudo docker compose "$@"
    return
  fi
  echo "[ERROR] Docker is not accessible, and sudo is not available." >&2
  exit 1
}

require_compose_file() {
  if [ ! -f "$ROOT/docker-compose.yml" ]; then
    echo "[ERROR] docker-compose.yml not found at: $ROOT/docker-compose.yml" >&2
    exit 1
  fi
}

# --- Begin interactive config ---
echo
echo "Local install will use Docker Compose (Postgres + server + web)."
echo "We'll now collect required settings (you can edit .env later)."

read -rp "App Port [3000]: " APP_PORT; APP_PORT="${APP_PORT:-3000}"
read -rp "Postgres Password [secret]: " PG_PW; PG_PW="${PG_PW:-secret}"
read -rp "Square Location ID: " SQUARE_LOCATION_ID
read -rp "Square Access Token (or leave blank if using OAuth later): " SQUARE_ACCESS_TOKEN
read -rp "Uber Store ID: " UBER_STORE_ID
read -rp "Uber Client ID: " UBER_CLIENT_ID
read -rp "Uber Client Secret: " UBER_CLIENT_SECRET

# --- Write .env (create from example if missing) ---
cp -n "$ROOT/.env.example" "$ENV_FILE" 2>/dev/null || true

# Build a fresh .env safely
{
  echo "APP_PORT=$APP_PORT"
  echo "NODE_ENV=production"
  echo "DATABASE_URL=postgresql://postgres:${PG_PW}@db:5432/menu_sync?schema=public"
  echo
  echo "# Square"
  echo "SQUARE_LOCATION_ID=${SQUARE_LOCATION_ID}"
  echo "SQUARE_ACCESS_TOKEN=${SQUARE_ACCESS_TOKEN}"
  echo
  echo "# Uber"
  echo "UBER_STORE_ID=${UBER_STORE_ID}"
  echo "UBER_CLIENT_ID=${UBER_CLIENT_ID}"
  echo "UBER_CLIENT_SECRET=${UBER_CLIENT_SECRET}"
} > "$ENV_FILE"

# --- Compose up ---
require_compose_file

echo
echo "Bringing up containers (this may pull images on first run)…"
dc -f "$ROOT/docker-compose.yml" up -d --build

echo
echo "Applying database migrations…"
# These may no-op the very first time; ignore failures of seed.
dc -f "$ROOT/docker-compose.yml" exec -T app npx prisma migrate deploy || true
dc -f "$ROOT/docker-compose.yml" exec -T app node server/node_modules/.bin/ts-node server/prisma/seed.ts || true

echo
echo "Done. Open: http://localhost:${APP_PORT}"
