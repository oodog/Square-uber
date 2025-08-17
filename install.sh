#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Config
# -----------------------------
REPO_URL="https://github.com/oodog/Square-uber.git"
APP_DIR="${APP_DIR:-$HOME/Square-uber}"

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
note(){ printf "\033[36m%s\033[0m\n" "$*"; }
warn(){ printf "\033[33m%s\033[0m\n" "$*"; }
err(){ printf "\033[31m%s\033[0m\n" "$*"; }

usage() {
  cat <<EOF
Usage:
  install.sh [--local | --azure] [--dir PATH]

Examples:
  # interactive (keep TTY):
  bash <(curl -sS https://raw.githubusercontent.com/oodog/Square-uber/refs/heads/main/install.sh)

  # non-interactive local:
  curl -sS https://raw.githubusercontent.com/oodog/Square-uber/refs/heads/main/install.sh | bash -s -- --local

  # choose install dir:
  curl -sS .../install.sh | bash -s -- --local --dir /opt/square-uber
EOF
}

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) MODE="local"; shift ;;
    --azure) MODE="azure"; shift ;;
    --dir) APP_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown arg: $1"; shift ;;
  esac
done

# -----------------------------
# Helpers
# -----------------------------
read_from_tty() {
  local prompt="$1" ; local varname="$2"
  if [ -t 0 ]; then
    read -rp "$prompt" "$varname"
  else
    exec 3</dev/tty || { err "No TTY. Use --local or --azure flags for non-interactive."; exit 1; }
    # shellcheck disable=SC2162
    read -u 3 -rp "$prompt" "$varname"
    exec 3<&-
  fi
}

precheck_tools() {
  for c in git curl awk sed printf; do
    command -v "$c" >/dev/null || { err "Missing required tool: $c"; exit 1; }
  done

  if ! command -v docker >/dev/null 2>&1; then
    cat <<'EOF'
[ERROR] Docker is not installed or not in PATH.

On Ubuntu 22.04, install with:

  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release; echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker
  sudo usermod -aG docker $USER
  newgrp docker

Re-run this installer afterwards.
EOF
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    err "[ERROR] Docker Compose plugin missing (package: docker-compose-plugin)."
    exit 1
  fi
}

fetch_repo() {
  if [ ! -d "$APP_DIR/.git" ]; then
    note "Cloning $REPO_URL into $APP_DIR..."
    git clone --depth=1 "$REPO_URL" "$APP_DIR"
  else
    note "Repo exists at $APP_DIR. Pulling latest..."
    (cd "$APP_DIR" && git pull --rebase)
  fi
}

# docker compose wrapper with sudo fallback
dc() {
  if docker info >/dev/null 2>&1; then
    docker compose "$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo docker info >/dev/null 2>&1 || {
      echo "[ERROR] Docker daemon not accessible (even with sudo). Try: sudo systemctl enable --now docker" >&2
      exit 1
    }
    sudo docker compose "$@"
    return
  fi
  echo "[ERROR] Docker is not accessible, and sudo is not available." >&2
  exit 1
}

ensure_files() {
  cd "$APP_DIR"

  # Create Dockerfile if missing
  if [ ! -f "Dockerfile" ]; then
    cat > Dockerfile <<'EOF'
# 1) Frontend
FROM node:20-alpine AS web
WORKDIR /app/web
COPY web/package*.json ./
RUN npm ci || npm install
COPY web/ .
RUN npm run build || echo "No web build step; continuing"

# 2) Backend
FROM node:20-alpine AS server
WORKDIR /app/server
COPY server/package*.json ./
RUN npm ci || npm install
COPY server/ .
RUN npm run build || echo "No server build step; continuing"

# 3) Runtime
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=server /app/server /app/server
COPY --from=web /app/web/dist /app/web/dist
RUN npm -C /app/server ci --omit=dev || npm -C /app/server install --omit=dev
EXPOSE 8080
CMD ["node", "server/dist/index.js"]
EOF
  fi

  # Create docker-compose.yml if missing
  if [ ! -f "docker-compose.yml" ]; then
    cat > docker-compose.yml <<'EOF'
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD:-secret}
      POSTGRES_DB: menu_sync
    volumes:
      - dbdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 10

  app:
    build:
      context: .
      dockerfile: Dockerfile
    depends_on:
      db:
        condition: service_healthy
    env_file: .env
    ports:
      - "${APP_PORT:-3000}:8080"
    command: >
      bash -lc "npx prisma migrate deploy || true && node server/dist/index.js"

volumes:
  dbdata: {}
EOF
  fi

  # Validate compose file syntax
  docker compose config >/dev/null
}

write_env_interactive() {
  cd "$APP_DIR"
  local env_file=".env"

  bold ""
  bold "Local install will use Docker Compose (Postgres + server + web)."
  echo "We'll now collect required settings (you can edit .env later)."

  local APP_PORT PG_PW SQUARE_LOCATION_ID SQUARE_ACCESS_TOKEN UBER_STORE_ID UBER_CLIENT_ID UBER_CLIENT_SECRET
  read_from_tty "App Port [3000]: " APP_PORT
  read_from_tty "Postgres Password [secret]: " PG_PW
  read_from_tty "Square Location ID: " SQUARE_LOCATION_ID
  read_from_tty "Square Access Token (or leave blank if using OAuth later): " SQUARE_ACCESS_TOKEN
  read_from_tty "Uber Store ID: " UBER_STORE_ID
  read_from_tty "Uber Client ID: " UBER_CLIENT_ID
  read_from_tty "Uber Client Secret: " UBER_CLIENT_SECRET

  # defaults & validation
  APP_PORT="${APP_PORT:-3000}"
  if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]]; then
    warn "Invalid port '$APP_PORT'. Using 3000."
    APP_PORT="3000"
  fi
  PG_PW="${PG_PW:-secret}"

  # write .env fresh
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
  } > "$env_file"
}

run_local() {
  precheck_tools
  fetch_repo
  ensure_files
  write_env_interactive

  note ""
  note "Bringing up containers (this may pull images on first run)…"
  dc -f "$APP_DIR/docker-compose.yml" up -d --build

  note ""
  note "Applying database migrations (best-effort)…"
  # These may no-op on first run; ignore failures.
  dc -f "$APP_DIR/docker-compose.yml" exec -T app npx prisma migrate deploy || true
  dc -f "$APP_DIR/docker-compose.yml" exec -T app node server/node_modules/.bin/ts-node server/prisma/seed.ts || true

  bold ""
  bold "Done. Open: http://localhost:$(grep -E '^APP_PORT=' "$APP_DIR/.env" | cut -d= -f2 | tr -d '[:space:]')"
}

run_azure() {
  precheck_tools
  fetch_repo
  ensure_files
  # Defer to your azure script (can be interactive). Keeps this installer clean.
  if [ -f "$APP_DIR/scripts/azure.sh" ]; then
    bash "$APP_DIR/scripts/azure.sh"
  else
    err "scripts/azure.sh not found. Pull latest repo or add Azure deploy script."
  fi
}

main_menu() {
  bold "Square ↔ Uber Setup"
  echo "1) Install / Run Locally (Docker Compose)"
  echo "2) Deploy to Azure (App Service + Postgres + Key Vault)"
  echo "q) Quit"
  local choice=""
  read_from_tty "Choose an option: " choice
  case "$choice" in
    1) run_local ;;
    2) run_azure ;;
    q|Q) exit 0 ;;
    *) err "Invalid choice"; main_menu ;;
  esac
}

# -----------------------------
# Entry
# -----------------------------
case "$MODE" in
  local) run_local ;;
  azure) run_azure ;;
  "") main_menu ;;
esac
