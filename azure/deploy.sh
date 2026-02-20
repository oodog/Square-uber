#!/bin/bash
# Azure deployment script - estimated cost: $2-8/month
# Prerequisites: Azure CLI (logged in), run from project root or azure/ folder
#
# Usage:
#   bash azure/deploy.sh
#   bash azure/deploy.sh --resource-group my-rg --location eastus

set -e

# ─── Config (override via args) ────────────────────────────────────────────────
RESOURCE_GROUP="rg-mangkok"
LOCATION="australiaeast"
ACR_NAME="mangkokcr"
APP_NAME="mangkok-menu-sync"
IMAGE_NAME="square-uber-square"

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --location)       LOCATION="$2";       shift 2 ;;
    --acr-name)       ACR_NAME="$2";       shift 2 ;;
    --app-name)       APP_NAME="$2";       shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# ─── Resolve project root ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# ─── Read secrets from .env.local ──────────────────────────────────────────────
ENV_FILE=".env.local"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ .env.local not found at $PROJECT_ROOT/$ENV_FILE"
  echo "   Copy .env.example → .env.local and fill in your secrets."
  exit 1
fi

get_env() { grep -E "^${1}=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | tr -d '"' ; }

NEXTAUTH_SECRET=$(get_env NEXTAUTH_SECRET)
GOOGLE_CLIENT_ID=$(get_env GOOGLE_CLIENT_ID)
GOOGLE_CLIENT_SECRET=$(get_env GOOGLE_CLIENT_SECRET)
GITHUB_CLIENT_SECRET=$(get_env GITHUB_CLIENT_SECRET)

if [[ -z "$NEXTAUTH_SECRET" ]]; then
  echo "⚠️  NEXTAUTH_SECRET not set in .env.local — generating one for you..."
  NEXTAUTH_SECRET=$(openssl rand -base64 32)
  echo "   Generated: $NEXTAUTH_SECRET"
  echo "   Add this to your .env.local: NEXTAUTH_SECRET=\"$NEXTAUTH_SECRET\""
fi

echo "🚀 Deploying to Azure..."
echo "   Resource Group : $RESOURCE_GROUP"
echo "   Location       : $LOCATION"
echo "   ACR             : $ACR_NAME"
echo "   App             : $APP_NAME"
echo ""

# ─── 1. Register providers (idempotent) ────────────────────────────────────────
echo "[1/5] Ensuring resource providers are registered..."
az provider register --namespace Microsoft.App --wait -o none
az provider register --namespace Microsoft.ContainerRegistry --wait -o none

# ─── 2. Create Resource Group ──────────────────────────────────────────────────
echo "[2/5] Creating resource group '$RESOURCE_GROUP'..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o none

# ─── 3. Create Azure Container Registry ────────────────────────────────────────
echo "[3/5] Creating Container Registry '$ACR_NAME'..."
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true \
  -o none

# ─── 4. Build & push Docker image via ACR Tasks ────────────────────────────────
echo "[4/5] Building & pushing Docker image (this takes ~3-5 min)..."
az acr build \
  --registry $ACR_NAME \
  --image "${IMAGE_NAME}:latest" \
  . \
  -o none

# ─── 5. Deploy Bicep ───────────────────────────────────────────────────────────
echo "[5/5] Deploying Container App via Bicep..."
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file azure/main.bicep \
  --parameters \
      appName=$APP_NAME \
      containerImage="${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest" \
      nextauthSecret="$NEXTAUTH_SECRET" \
      googleClientId="$GOOGLE_CLIENT_ID" \
      googleClientSecret="$GOOGLE_CLIENT_SECRET" \
      githubClientSecret="$GITHUB_CLIENT_SECRET" \
  -o none

# ─── Done ──────────────────────────────────────────────────────────────────────
APP_URL=$(az containerapp show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query 'properties.configuration.ingress.fqdn' \
  -o tsv)

echo ""
echo "✅ Deployed successfully!"
echo "   URL: https://$APP_URL"
echo ""
echo "⚠️  Next steps:"
echo "  1. Custom domain: Azure Portal → Container App → Custom domains"
echo "     CNAME  app.mangkokavenue.com  →  $APP_URL"
echo "  2. Update NEXTAUTH_URL and UBER_REDIRECT_URI in the Bicep env vars"
echo "  3. Production SQLite note: current setup uses EmptyDir (resets on restart)"
echo "     Upgrade to Azure Files for persistent storage in production."
