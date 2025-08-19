#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Square-Uber Installer — full self-healing deploy script
#  • Auto-installs Docker & Compose on Ubuntu/Debian (apt)
#  • Works anywhere (not tied to home dir)
#  • Normalizes config files, removes broken .env, writes validated .env
#  • Runs with sudo fallback so no re-login needed
#  • One-liner install: bash <(curl …/install.sh)
# ==============================================================================

REPO_URL="https://github.com/oodog/Square-uber.git"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
note() { printf "\033[36m%s\033[0m\n" "$*"; }
warn() { printf "\033[33m%s\033[0m\n" "$*"; }
err() { printf "\033[31m%s\033[0m\n" "$*"; }

# Choose an install directory that's writable
choose_default_dir() {
  if [ -w /opt ] && [ -d /opt ]; then echo "/opt/square-uber"; return; fi
  if [ -w "$PWD" ]; then echo "$PWD/Square-uber"; return; fi
  echo "${HOME:-/tmp}/Square-uber"
}
APP_DIR="${APP_DIR:-$(choose_default_dir)}"
MODE=""; ASSUME_YES="no"

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) MODE="local"; shift ;;
    --azure) MODE="azure"; shift ;;
    --dir) APP_DIR="$2"; shift 2 ;;
    --yes) ASSUME_YES="yes"; shift ;;
    -h|--help)
      cat <<EOF
Usage: install.sh [--local | --azure] [--dir PATH] [--yes]

Examples:
  bash <(curl -sS <url>/install.sh)
  bash <(curl -sS <url>/install.sh) --local --yes
EOF
      exit 0
      ;;
    *) warn "Unknown arg: $1"; shift ;;
  esac
done

# Read from TTY if piped; respect --yes
read_from_tty() {
  local prompt="$1" var="$2" def="${3-}"
  if [ "$ASSUME_YES" == "yes" ]; then printf -v "$var" "%s" "$def"; return; fi
  if [ -t 0 ]; then
    read -rp "$prompt" "$var"
    [[ -z "${!var}" && -n "$def" ]] && printf -v "$var" "%s" "$def"
  else
    exec 3</dev/tty || { err "No TTY; use --local/--azure/--yes."; exit 1; }
    read -u 3 -rp "$prompt" "$var"
    exec 3<&-
    [[ -z "${!var}" && -n "$def" ]] && printf -v "$var" "%s" "$def"
  fi
}

# Docker and Compose setup for apt-based systems
is_apt() { command -v apt-get >/dev/null 2>&1; }
have_sudo() { command -v sudo >/dev/null 2>&1; }

auto_install_docker_apt() {
  note "Installing Docker + Compose (apt)…"
  have_sudo || { err "sudo required."; exit 1; }
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release
  sudo install -m 0755 -d /etc/apt/keyrings || true
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    || curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  codename="$(. /etc/os-release; echo "${VERSION_CODENAME:-stable}")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$(. /etc/os-release; echo ${ID:-ubuntu}) \
${codename} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker || true
  getent group docker >/dev/null 2>&1 && sudo usermod -aG docker "$USER" || true
  note "Docker installed."
}

ensure_docker() {
  command -v docker >/dev/null 2>&1 || { is_apt && auto_install_docker_apt || { err "Install Docker manually."; exit 1; }; }
  docker compose version >/dev/null 2>&1 || { is_apt || { err "Compose plugin missing."; exit 1; }; note "Installing Compose plugin…"; have_sudo || { err "sudo needed."; exit 1; }; sudo apt-get update -y && sudo apt-get install -y docker-compose-plugin; }
  docker info >/dev/null 2>&1 || { have_sudo || { err "Docker daemon unreachable."; exit 1; }; sudo systemctl enable --now docker || true; sleep 2; sudo docker info >/dev/null 2>&1 || { err "Docker still unreachable."; exit 1; }; }
}

dc() {
  if docker info >/dev/null 2>&1; then docker compose "$@"; else sudo docker compose "$@"; fi
}

# Clone or update the repo
fetch_repo() {
  mkdir -p "$(dirname "$APP_DIR")"
  if [ -d "$APP_DIR/.git" ]; then
    note "Updating repo at $APP_DIR…"
    (cd "$APP_DIR" && git pull --rebase)
  else
    note "Cloning repo into $APP_DIR…"
    git clone --depth=1 "$REPO_URL" "$APP_DIR"
  fi
}

# Normalize line endings and tabs
normalize() { awk 'sub(/\r$/,"")1' "$1" > "$1.unix" && mv "$1.unix" "$1" || true; sed -i $'s/\t/  /g' "$1" || true; }

# Write defaults if missing
write_default_dockerfile() {
cat > Dockerfile <<'EOF'
FROM node:20-alpine AS web
WORKDIR /app/web
COPY web/package*.json ./
RUN npm ci || npm install
COPY web/ .
RUN npm run build || echo "No web build"

FROM node:20-alpine AS server
WORKDIR /app/server
COPY server/package*.json ./
RUN npm ci || npm install
COPY server/ .
RUN npm run build || echo "No server build"

FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=server /app/server /app/server
COPY --from=web /app/web/dist /app/web/dist
RUN npm -C /app/server ci --omit=dev || npm -C /app/server install --omit=dev
EXPOSE 8080
CMD ["node", "server/dist/index.js"]
EOF
}

write_default_compose() {
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
      test: ["CMD-SHELL","pg_isready -U postgres"]
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
}

# Always create a minimal .env so compose can validate
ensure_env_minimal() {
  cd "$APP_DIR"
  cat > .env <<'EOF'
APP_PORT=3000
NODE_ENV=production
DATABASE_URL=postgresql://postgres:secret@db:5432/menu_sync?schema=public

# Square
SQUARE_LOCATION_ID=
SQUARE_ACCESS_TOKEN=

# Uber
UBER_STORE_ID=
UBER_CLIENT_ID=
UBER_CLIENT_SECRET=
EOF
}

ensure_files() {
  cd "$APP_DIR"
  [ -f Dockerfile ] || { warn "Generating default Dockerfile..."; write_default_dockerfile; }
  [ -f docker-compose.yml ] || { warn "Generating default docker-compose.yml..."; write_default_compose; }
  normalize Dockerfile; normalize docker-compose.yml
  ensure_env_minimal
  docker compose config >/dev/null 2>&1 || { warn "compose invalid; rewriting."; write_default_compose; docker compose config >/dev/null; }
}

# Fully prompt and write final .env
write_env_full() {
  cd "$APP_DIR"
  bold "Configure Sync Portal"
  read_from_tty "App Port [3000]: " APP_PORT "3000"
  read_from_tty "Postgres Password [secret]: " PG_PW "secret"
  read_from_tty "Square Location ID: " SQUARE_LOCATION_ID ""
  read_from_tty "Square Access Token: " SQUARE_ACCESS_TOKEN ""
  read_from_tty "Uber Store ID: " UBER_STORE_ID ""
  read_from_tty "Uber Client ID: " UBER_CLIENT_ID ""
  read_from_tty "Uber Client Secret: " UBER_CLIENT_SECRET ""

  [[ "$APP_PORT" =~ ^[0-9]+$ ]] || { warn "Invalid port; using 3000"; APP_PORT=3000; }

  cat > .env <<EOF
APP_PORT=$APP_PORT
NODE_ENV=production
DATABASE_URL=postgresql://postgres:${PG_PW}@db:5432/menu_sync?schema=public

# Square
SQUARE_LOCATION_ID=${SQUARE_LOCATION_ID}
SQUARE_ACCESS_TOKEN=${SQUARE_ACCESS_TOKEN}

# Uber
UBER_STORE_ID=${UBER_STORE_ID}
UBER_CLIENT_ID=${UBER_CLIENT_ID}
UBER_CLIENT_SECRET=${UBER_CLIENT_SECRET}
EOF
  note "Wrote .env"
}

run_local() {
  for cmd in git curl awk sed printf; do command -v "$cmd" >/dev/null || { err "Missing required tool: $cmd"; exit 1; }; done
  ensure_docker
  fetch_repo
  ensure_files
  write_env_full
  

  note "Launching containers (this may pull images)…"
  dc -f "$APP_DIR/docker-compose.yml" up -d --build

  note "Applying migrations (best-effort)…"
  dc -f "$APP_DIR/docker-compose.yml" exec -T app npx prisma migrate deploy || true
  dc -f "$APP_DIR/docker-compose.yml" exec -T app node server/node_modules/.bin/ts-node server/prisma/seed.ts || true

  bold "Done! Visit: http://localhost:$(grep -E '^APP_PORT=' .env | cut -d= -f2)"
}

run_azure() {
  for cmd in git curl awk sed printf; do command -v "$cmd" >/

Interrupted due to length.
::contentReference[oaicite:0]{index=0}
