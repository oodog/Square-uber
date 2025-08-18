#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/oodog/Square-uber.git"

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
note(){ printf "\033[36m%s\033[0m\n" "$*"; }
warn(){ printf "\033[33m%s\033[0m\n" "$*"; }
err(){ printf "\033[31m%s\033[0m\n" "$*"; }

choose_default_dir() {
  if [ -w /opt ] && [ -d /opt ]; then echo "/opt/square-uber"; return; fi
  if [ -w "$PWD" ]; then echo "$PWD/Square-uber"; return; fi
  echo "${HOME:-/tmp}/Square-uber"
}

APP_DIR="${APP_DIR:-$(choose_default_dir)}"
MODE=""; ASSUME_YES="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) MODE="local"; shift ;;
    --azure) MODE="azure"; shift ;;
    --dir) APP_DIR="$2"; shift 2 ;;
    --yes) ASSUME_YES="yes"; shift ;;
    -h|--help) cat <<EOF
Usage: install.sh [--local|--azure] [--dir PATH] [--yes]
EOF
      exit 0 ;;
    *) warn "Unknown arg: $1"; shift ;;
  esac
done

read_from_tty() {
  local prompt="$1" var="$2" def="${3-}"
  if [[ "$ASSUME_YES" == "yes" ]]; then printf -v "$var" "%s" "$def"; return; fi
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

is_apt(){ command -v apt-get >/dev/null 2>&1; }
have_sudo(){ command -v sudo >/dev/null 2>&1; }

auto_install_docker_apt() {
  note "Installing Docker Engine + Compose (apt)…"
  have_sudo || { err "sudo required to auto-install Docker"; exit 1; }
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release
  sudo install -m 0755 -d /etc/apt/keyrings || true
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || \
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  local codename; codename="$(. /etc/os-release; echo "${VERSION_CODENAME:-stable}")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo ${ID:-ubuntu}) ${codename} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker || true
  getent group docker >/dev/null 2>&1 && sudo usermod -aG docker "$USER" || true
  note "Docker installed."
}

ensure_docker() {
  command -v docker >/dev/null 2>&1 || { is_apt && auto_install_docker_apt || { err "Install Docker first."; exit 1; }; }
  docker compose version >/dev/null 2>&1 || {
    is_apt || { err "Compose plugin missing and auto-install unsupported"; exit 1; }
    note "Installing Compose plugin…"; have_sudo || { err "sudo required"; exit 1; }
    sudo apt-get update -y && sudo apt-get install -y docker-compose-plugin
  }
  docker info >/dev/null 2>&1 || { have_sudo || { err "Docker daemon not reachable"; exit 1; }; sudo systemctl enable --now docker || true; sleep 2; sudo docker info >/dev/null 2>&1 || { err "Docker still not reachable"; exit 1; }; }
}

dc() {
  if docker info >/dev/null 2>&1; then docker compose "$@"; else sudo docker compose "$@"; fi
}

fetch_repo() {
  mkdir -p "$(dirname "$APP_DIR")"
  if [ ! -d "$APP_DIR/.git" ]; then
    note "Cloning $REPO_URL into $APP_DIR..."
    git clone --depth=1 "$REPO_URL" "$APP_DIR"
  else
    note "Repo exists at $APP_DIR. Pulling latest..."
    (cd "$APP_DIR" && git pull --rebase)
  fi
}

normalize() { awk 'sub(/\r$/,"")1' "$1" > "$1.unix" && mv "$1.unix" "$1" || true; sed -i $'s/\t/  /g' "$1" || true; }

write_default_dockerfile() {
cat > Dockerfile <<'EOF'
FROM node:20-alpine AS web
WORKDIR /app/web
COPY web/package*.json ./
RUN npm ci || npm install
COPY web/ .
RUN npm run build || echo "No web build step; continuing"
FROM node:20-alpine AS server
WORKDIR /app/server
COPY server/package*.json ./
RUN npm ci || npm install
COPY server/ .
RUN npm run build || echo "No server build step; continuing"
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
}

ensure_env_minimal() {
  cd "$APP_DIR"
  # ALWAYS create fresh minimal env to avoid picking up a broken committed .env
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
  [ -f Dockerfile ] || { warn "Dockerfile missing; writing default."; write_default_dockerfile; }
  [ -f docker-compose.yml ] || { warn "docker-compose.yml missing; writing default."; write_default_compose; }
  normalize Dockerfile; normalize docker-compose.yml
  ensure_env_minimal
  docker compose config >/dev/null || { warn "compose invalid; rewriting default…"; write_default_compose; docker compose config >/dev/null; }
}

write_env_full() {
  cd "$APP_DIR"
  bold ""; bold "Local install will use Docker Compose (Postgres + server + web)."
  echo "We'll now collect required settings (you can edit .env later)."
  local APP_PORT PG_PW SQUARE_LOCATION_ID SQUARE_ACCESS_TOKEN UBER_STORE_ID UBER_CLIENT_ID UBER_CLIENT_SECRET
  read_from_tty "App Port [3000]: " APP_PORT "3000"
  read_from_tty "Postgres Password [secret]: " PG_PW "secret"
  read_from_tty "Square Location ID: " SQUARE_LOCATION_ID ""
  read_from_tty "Square Access Token (or leave blank if using OAuth later): " SQUARE_ACCESS_TOKEN ""
  read_from_tty "Uber Store ID: " UBER_STORE_ID ""
  read_from_tty "Uber Client ID: " UBER_CLIENT_ID ""
  read_from_tty "Uber Client Secret: " UBER_CLIENT_SECRET ""
  [[ "$APP_PORT" =~ ^[0-9]+$ ]] || { warn "Invalid port '$APP_PORT'; using 3000."; APP_PORT=3000; }
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
  # prerequisites
  for c in git curl awk sed printf; do command -v "$c" >/dev/null || { err "Missing tool: $c"; exit 1; }; done
  ensure_docker
  # repo + files + env
  fetch_repo
  ensure_files         # writes minimal .env and validates compose
  write_env_full       # overwrites .env with your inputs
  # run
  note ""; note "Bringing up containers (this may pull images on first run)…"
  dc -f "$APP_DIR/docker-compose.yml" up -d --build
  note ""; note "Applying database migrations (best-effort)…"
  dc -f "$APP_DIR/docker-compose.yml" exec -T app npx prisma migrate deploy || true
  dc -f "$APP_DIR/docker-compose.yml" exec -T app node server/node_modules/.bin/ts-node server/prisma/seed.ts || true
  bold ""; bold "Done. Open: http://localhost:$(grep -E '^APP_PORT=' "$APP_DIR/.env" | cut -d= -f2 | tr -d '[:space:]')"
}

run_azure() {
  for c in git curl awk sed printf; do command -v "$c" >/dev/null || { err "Missing tool: $c"; exit 1; }; done
  ensure_docker
  fetch_repo
  ensure_files
  [ -f "$APP_DIR/scripts/azure.sh" ] && bash "$APP_DIR/scripts/azure.sh" || err "scripts/azure.sh not found."
}

main_menu() {
  bold "Square ↔ Uber Setup"
  echo "1) Install / Run Locally (Docker Compose)"
  echo "2) Deploy to Azure (App Service + Postgres + Key Vault)"
  echo "q) Quit"
  local choice=""; read_from_tty "Choose an option: " choice
  case "$choice" in
    1) run_local ;;
    2) run_azure ;;
    q|Q) exit 0 ;;
    *) err "Invalid choice"; main_menu ;;
  esac
}

case "$MODE" in
  local) run_local ;;
  azure) run_azure ;;
  *) main_menu ;;
esac

