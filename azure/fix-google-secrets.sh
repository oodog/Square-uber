#!/bin/bash
set -e

# Read Google OAuth credentials from .env.local
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.local"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env.local not found at $ENV_FILE"
  exit 1
fi

GOOGLE_CLIENT_ID=$(grep '^GOOGLE_CLIENT_ID=' "$ENV_FILE" | sed 's/^GOOGLE_CLIENT_ID=//' | tr -d '"')
GOOGLE_CLIENT_SECRET=$(grep '^GOOGLE_CLIENT_SECRET=' "$ENV_FILE" | sed 's/^GOOGLE_CLIENT_SECRET=//' | tr -d '"')

if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
  echo "Error: GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET not found in .env.local"
  exit 1
fi

echo "Client ID: ${GOOGLE_CLIENT_ID:0:20}..."
echo "Secret ends with: ...${GOOGLE_CLIENT_SECRET: -5}"

echo "Updating secrets..."
az containerapp secret set \
  --name mangkok-menu-sync \
  --resource-group rg-mangkok \
  --secrets \
    "google-client-id=${GOOGLE_CLIENT_ID}" \
    "google-client-secret=${GOOGLE_CLIENT_SECRET}" \
  -o none

echo "Deploying new revision..."
az containerapp update \
  --name mangkok-menu-sync \
  --resource-group rg-mangkok \
  -o none

echo "Done"
