#!/bin/bash
set -e
cd ~/square-uber-build

ENV_FILE='/mnt/c/project/square-uber-square/.env.local'
get_env() { grep -E "^${1}=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | tr -d '"'; }

NEXTAUTH_SECRET=$(get_env NEXTAUTH_SECRET)
GOOGLE_CLIENT_ID=$(get_env GOOGLE_CLIENT_ID)
GOOGLE_CLIENT_SECRET=$(get_env GOOGLE_CLIENT_SECRET)
GITHUB_CLIENT_SECRET=$(get_env GITHUB_CLIENT_SECRET)

echo "Secrets loaded: NEXTAUTH_SECRET=${#NEXTAUTH_SECRET}chars, GID=${#GOOGLE_CLIENT_ID}chars"

az deployment group create \
  --resource-group rg-mangkok \
  --template-file azure/main.bicep \
  --parameters \
      appName=mangkok-menu-sync \
      acrName=mangkokcr \
      "containerImage=mangkokcr.azurecr.io/square-uber-square:latest" \
      "nextauthSecret=$NEXTAUTH_SECRET" \
      "googleClientId=$GOOGLE_CLIENT_ID" \
      "googleClientSecret=$GOOGLE_CLIENT_SECRET" \
      "githubClientSecret=$GITHUB_CLIENT_SECRET" \
  --query 'properties.outputs' \
  -o json
