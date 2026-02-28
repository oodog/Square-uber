#!/bin/bash
set -e
ENV_FILE='/mnt/c/project/square-uber-square/.env.local'
get_env() { grep -E "^${1}=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | tr -d '"'; }

GOOGLE_CLIENT_ID=$(get_env GOOGLE_CLIENT_ID)
GOOGLE_CLIENT_SECRET=$(get_env GOOGLE_CLIENT_SECRET)
NEXTAUTH_SECRET=$(get_env NEXTAUTH_SECRET)

echo "Updating secrets on Container App..."
az containerapp secret set \
  --name mangkok-menu-sync \
  --resource-group rg-mangkok \
  --secrets \
    "google-client-id=$GOOGLE_CLIENT_ID" \
    "google-client-secret=$GOOGLE_CLIENT_SECRET" \
    "nextauth-secret=$NEXTAUTH_SECRET" \
  -o none

echo "Deploying new revision to pick up updated secrets..."
az containerapp update \
  --name mangkok-menu-sync \
  --resource-group rg-mangkok \
  --revision-suffix v12 \
  -o none

echo "Done — revision v12 deploying with updated secrets"
