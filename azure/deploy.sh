#!/bin/bash
# Azure deployment script - estimated cost: $2-8/month
# Prerequisites: Azure CLI, Docker

set -e

RESOURCE_GROUP="rg-mangkok"
LOCATION="australiaeast"
ACR_NAME="mangkokcr"
APP_NAME="mangkok-menu-sync"
IMAGE_NAME="square-uber-square"

echo "🚀 Deploying Mangkok Avenue Menu Sync to Azure..."

# 1. Create Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION

# 2. Create Azure Container Registry (Basic ~$5/month - or use GitHub Container Registry for free)
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true

# 3. Build & push Docker image
az acr build --registry $ACR_NAME --image $IMAGE_NAME:latest .

# 4. Deploy Bicep template
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file azure/main.bicep \
  --parameters appName=$APP_NAME \
               containerImage="${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest"

echo "✅ Deployed! Visit https://app.mangkokavenue.com"
echo ""
echo "⚠️  Next steps:"
echo "  1. Add custom domain 'app.mangkokavenue.com' in Azure Portal → Container App → Custom domains"
echo "  2. Set secrets via: az containerapp secret set --name $APP_NAME --resource-group $RESOURCE_GROUP --secrets nextauth-secret=YOUR_SECRET"
echo "  3. Configure DNS: CNAME app.mangkokavenue.com → (shown in Azure Portal)"
