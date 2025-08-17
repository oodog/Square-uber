#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
cp -n "$ROOT/.env.example" "$ENV_FILE" || true

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

# write .env (preserve existing, update keys)
awk -v k="APP_PORT" -v v="$APP_PORT" 'BEGIN{print k"="v}' > "$ENV_FILE.tmp"
for kv in \
  "DATABASE_URL=postgresql://postgres:${PG_PW}@db:5432/menu_sync?schema=public" \
  "SQUARE_LOCATION_ID=${SQUARE_LOCATION_ID}" \
  "SQUARE_ACCESS_TOKEN=${SQUARE_ACCESS_TOKEN}" \
  "UBER_STORE_ID=${UBER_STORE_ID}" \
  "UBER_CLIENT_ID=${UBER_CLIENT_ID}" \
  "UBER_CLIENT_SECRET=${UBER_CLIENT_SECRET}" \
  "NODE_ENV=production"
do echo "$kv" >> "$ENV_FILE.tmp"; done
mv "$ENV_FILE.tmp" "$ENV_FILE"

echo
docker compose -f "$ROOT/docker-compose.yml" up -d --build

echo
echo "Applying database migrations..."
docker compose -f "$ROOT/docker-compose.yml" exec -T app npx prisma migrate deploy
docker compose -f "$ROOT/docker-compose.yml" exec -T app node server/node_modules/.bin/ts-node server/prisma/seed.ts || true

echo
echo "Done. Open http://localhost:${APP_PORT}"
