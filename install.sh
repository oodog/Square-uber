#!/usr/bin/env bash
set -euo pipefail

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

When no flag is provided, an interactive menu is shown.
Examples:
  # interactive with preserved TTY:
  bash <(curl -sS https://raw.githubusercontent.com/oodog/Square-uber/refs/heads/main/install.sh)

  # non-interactive local:
  curl -sS https://raw.githubusercontent.com/oodog/Square-uber/refs/heads/main/install.sh | bash -s -- --local
EOF
}

# Parse flags
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

precheck() {
  bash "$APP_DIR/scripts/helpers.sh" --precheck || true
}

read_from_tty() {
  # Read a single line from /dev/tty even if stdin is a pipe
  local prompt="$1"
  local varname="$2"
  if [ -t 0 ]; then
    read -rp "$prompt" "$varname"
  else
    # shellcheck disable=SC2162
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

ensure_git
fetch_repo
precheck

case "$MODE" in
  local) bash "$APP_DIR/scripts/local.sh" ;;
  azure) bash "$APP_DIR/scripts/azure.sh" ;;
  "") main_menu ;;
esac
