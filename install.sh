#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/oodog/Square-uber.git"
APP_DIR="${APP_DIR:-$HOME/Square-uber}"

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
note(){ printf "\033[36m%s\033[0m\n" "$*"; }
warn(){ printf "\033[33m%s\033[0m\n" "$*"; }
err(){ printf "\033[31m%s\033[0m\n" "$*"; }

# --- NEW: Precheck function ---
precheck() {
  # basic commands
  for c in git curl awk sed printf; do
    command -v "$c" >/dev/null || { err "Missing required tool: $c"; exit 1; }
  done

  # docker
  if ! command -v docker >/dev/null 2>&1; then
    cat <<'EOF'
[ERROR] Docker is not installed or not in PATH.

On Ubuntu 22.04, install Docker with:

  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(. /etc/os-release; echo $VERSION_CODENAME) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker
  sudo usermod -aG docker $USER && newgrp docker

After that, re-run the installer.
EOF
    exit 1
  fi

  # docker compose
  if ! docker compose version >/dev/null 2>&1; then
    err "[ERROR] Docker Compose plugin is missing (package: docker-compose-plugin)."
    exit 1
  fi
}

ensure_git() { command -v git >/dev/null 2>&1 || { err "git is required"; exit 1; }; }

fetch_repo() {
  if [ ! -d "$APP_DIR/.git" ]; then
    note "Cloning $REPO_URL into $APP_DIR..."
    git clone --depth=1 "$REPO_URL" "$APP_DIR"
  else
    note "Repo exists at $APP_DIR. Pulling latest..."
    (cd "$APP_DIR" && git pull --rebase)
  fi
}

read_from_tty() {
  local prompt="$1"
  local varname="$2"
  if [ -t 0 ]; then
    read -rp "$prompt" "$varname"
  else
    exec 3</dev/tty || { err "No TTY available; use --local or --azure flags."; exit 1; }
    read -u 3 -rp "$prompt" "$varname"
    exec 3<&-
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
    1) bash "$APP_DIR/scripts/local.sh" ;;
    2) bash "$APP_DIR/scripts/azure.sh" ;;
    q|Q) exit 0 ;;
    *) err "Invalid choice"; main_menu ;;
  esac
}

# --- run everything ---
precheck
ensure_git
fetch_repo
main_menu
