#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/oodog/Square-uber.git"
APP_DIR="${APP_DIR:-$HOME/Square-uber}"

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
note(){ printf "\033[36m%s\033[0m\n" "$*"; }
warn(){ printf "\033[33m%s\033[0m\n" "$*"; }
err(){ printf "\033[31m%s\033[0m\n" "$*"; }

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

main_menu() {
  bold "Square ↔ Uber Setup"
  echo "1) Install / Run Locally (Docker Compose)"
  echo "2) Deploy to Azure (App Service + Postgres + Key Vault)"
  echo "q) Quit"
  read -rp "Choose an option: " choice
  case "$choice" in
    1) bash "$APP_DIR/scripts/local.sh" ;;
    2) bash "$APP_DIR/scripts/azure.sh" ;;
    q|Q) exit 0 ;;
    *) err "Invalid choice"; main_menu ;;
  esac
}

ensure_git
fetch_repo
bash "$APP_DIR/scripts/helpers.sh" --precheck
main_menu
