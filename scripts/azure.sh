#!/usr/bin/env bash
set -euo pipefail

# Requirements: az cli, Docker, logged in to Azure: az login
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/.env.example" >/dev/null 2>&1 || true

echo "Azure deploy will create: RG, ACR, Postgres (Flexible), Key Vault, App Service (Container)."
read -rp "Azure Subscription ID: " AZ_SUB
read -rp "Resource Group name [sq-uber-rg]: " RG; RG="${RG:-sq-uber-rg}"
read -rp "Region [australiaeast]: " LOC; LOC="${LOC:-australiaeast}"
read -rp "ACR name (globally unique) [squberacr$RANDOM]: " ACR; ACR="${ACR:-squberacr$RANDOM}"
read -rp "Postgres server name (unique) [squberpg$RANDOM]: " PG; PG="${PG:-squberpg$RANDOM}"
read -rp "App Service Plan name [sq-uber-plan]: " PLAN; PLAN="${PLAN:-sq-uber-plan}"
read -rp "Web App name (unique) [sq-uber-app-$RANDOM]: " APP; APP="${APP:-sq-uber-app-$RANDOM}"
read -rp "Key Vault name (unique) [sq-uber-kv-$RANDOM]: " KV; KV="${KV:-sq-uber-kv-$RANDOM}"

read -rp "Square Location ID: " SQUARE_LOCATION_ID
read -rsp "Square Access Token (leave blank if using OAuth later): " SQUARE_ACCESS_TOKEN; echo
read -rp "Uber Store ID: " UBER_STORE_ID
read -rp "Uber Client ID: " UBER_CLIENT_ID
read -rsp "Uber Client Secret: " UBER_CLIENT_SECRET; echo

az account set --subscription "$AZ_SUB"
az group create -n "$RG" -l "$LOC"

# ACR
az acr create -n "$ACR" -g "$RG" --sku Basic
az acr login -n "$ACR"

# Postgres Flexible
PG_PW=$(openssl rand -base64 24 | tr -d '=+/')
az postgres flexible-server create -g "$RG" -n "$PG" -l "$LOC" \
  --tier Burstable --sku-name B1ms --storage-size 32 \
  --version 16 --yes --password "$PG_PW"

# Allow access from App Service (we'll use VNet Integration later if needed)
az postgres flexible-server firewall-rule create -g "$RG" -n "$PG" \
  -r allowall --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255 >/dev/null

DB_HOST="${PG}.postgres.database.azure.com"
DB_URL="postgresql://postgres:${PG_PW}@${DB_HOST}:5432/menu_sync?sslmode=require"

# Key Vault
az keyvault create -n "$KV" -g "$RG" -l "$LOC"
az keyvault secret set --vault-name "$KV" --name "SQUARE-LOCATION-ID" --value "$SQUARE_LOCATION_ID" >/dev/null
az keyvault secret set --vault-name "$KV" --name "SQUARE-ACCESS-TOKEN" --value "$SQUARE_ACCESS_TOKEN" >/dev/null
az keyvault secret set --vault-name "$KV" --name "UBER-STORE-ID" --value "$UBER_STORE_ID" >/dev/null
az keyvault secret set --vault-name "$KV" --name "UBER-CLIENT-ID" --value "$UBER_CLIENT_ID" >/dev/null
az keyvault secret set --vault-name "$KV" --name "UBER-CLIENT-SECRET" --value "$UBER_CLIENT_SECRET" >/dev/null
az keyvault secret set --vault-name "$KV" --name "DATABASE-URL" --value "$DB_URL" >/dev/null

# Build & push image to ACR
IMG="${ACR}.azurecr.io/sq-uber:latest"
az acr build -r "$ACR" -g "$RG" -t "$IMG" "$ROOT"

# App Service Plan + Web App (container)
az appservice plan create -g "$RG" -n "$PLAN" --is-linux --sku B1
az webapp create -g "$RG" -p "$PLAN" -n "$APP" -i "$IMG"

# Give App access to Key Vault
IDENTITY_ID=$(az webapp identity assign -g "$RG" -n "$APP" --query principalId -o tsv)
KV_ID=$(az keyvault show -n "$KV" --query id -o tsv)
az role assignment create --assignee "$IDENTITY_ID" --role "Key Vault Secrets User" --scope "$KV_ID"

# Configure app settings (Key Vault references)
az webapp config appsettings set -g "$RG" -n "$APP" --settings \
  "APP_PORT=8080" \
  "NODE_ENV=production" \
  "SQUARE_LOCATION_ID=@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/SQUARE-LOCATION-ID)" \
  "SQUARE_ACCESS_TOKEN=@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/SQUARE-ACCESS-TOKEN)" \
  "UBER_STORE_ID=@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/UBER-STORE-ID)" \
  "UBER_CLIENT_ID=@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/UBER-CLIENT-ID)" \
  "UBER_CLIENT_SECRET=@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/UBER-CLIENT-SECRET)" \
  "DATABASE_URL=@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/DATABASE-URL)"

# Startup command & port
az webapp config set -g "$RG" -n "$APP" --generic-configurations '{"linuxFxVersion":"DOCKER|"}' >/dev/null
az webapp config set -g "$RG" -n "$APP" --startup-file "bash -lc 'npx prisma migrate deploy && node server/dist/index.js'"

echo
echo "Kicking app…"
az webapp restart -g "$RG" -n "$APP"

echo
echo "Done. Visit: https://${APP}.azurewebsites.net"
