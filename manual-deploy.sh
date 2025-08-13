#!/bin/bash

# Manual Azure Resource Creation Script
# This script creates resources one by one to avoid CLI response issues

set -euo pipefail

# Configuration
RESOURCE_GROUP="aj-microservices-rg"
LOCATION="eastus2"
NAME_PREFIX="ajdaprmicro"

echo "🚀 Manual Azure Resource Creation"
echo "================================="

# Create Container Registry
echo "📦 Creating Container Registry..."
az acr create \
    --resource-group $RESOURCE_GROUP \
    --name "${NAME_PREFIX}registry" \
    --sku Basic \
    --admin-enabled true \
    --location $LOCATION \
    --output none

echo "✅ Container Registry created"

# Create Log Analytics Workspace
echo "📊 Creating Log Analytics Workspace..."
az monitor log-analytics workspace create \
    --resource-group $RESOURCE_GROUP \
    --workspace-name "${NAME_PREFIX}logs" \
    --location $LOCATION \
    --sku PerGB2018 \
    --output none

echo "✅ Log Analytics Workspace created"

# Get Log Analytics details
WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group $RESOURCE_GROUP \
    --workspace-name "${NAME_PREFIX}logs" \
    --query customerId \
    --output tsv)

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show \
    --resource-group $RESOURCE_GROUP \
    --workspace-name "${NAME_PREFIX}logs" \
    --query id \
    --output tsv)

WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group $RESOURCE_GROUP \
    --workspace-name "${NAME_PREFIX}logs" \
    --query primarySharedKey \
    --output tsv)

echo "📱 Creating Application Insights..."
az monitor app-insights component create \
    --resource-group $RESOURCE_GROUP \
    --app "${NAME_PREFIX}insights" \
    --location $LOCATION \
    --kind web \
    --workspace "$WORKSPACE_RESOURCE_ID" \
    --output none

echo "✅ Application Insights created"

# Create Redis Cache
echo "🔴 Creating Redis Cache..."
az redis create \
    --resource-group $RESOURCE_GROUP \
    --name "${NAME_PREFIX}redis" \
    --location $LOCATION \
    --sku Basic \
    --vm-size c0 \
    --enable-non-ssl-port false \
    --minimum-tls-version 1.2 \
    --output none

echo "✅ Redis Cache created (this may take 10-20 minutes)"

# Create Container Apps Environment
echo "🏗️ Creating Container Apps Environment..."
az containerapp env create \
    --resource-group $RESOURCE_GROUP \
    --name "${NAME_PREFIX}-env" \
    --location $LOCATION \
    --logs-workspace-id $WORKSPACE_ID \
    --logs-workspace-key $WORKSPACE_KEY \
    --output none

echo "✅ Container Apps Environment created"

# Get Redis connection details
REDIS_HOST=$(az redis show \
    --resource-group $RESOURCE_GROUP \
    --name "${NAME_PREFIX}redis" \
    --query hostName \
    --output tsv)

REDIS_KEY=$(az redis list-keys \
    --resource-group $RESOURCE_GROUP \
    --name "${NAME_PREFIX}redis" \
    --query primaryKey \
    --output tsv)

# Create Dapr State Store Component
echo "🔧 Creating Dapr State Store..."
cat > statestore-temp.yaml << EOF
componentType: state.redis
version: v1
metadata:
- name: redisHost
  value: ${REDIS_HOST}:6380
- name: redisPassword
  secretRef: redis-password
- name: enableTLS
  value: "true"
secrets:
- name: redis-password
  value: ${REDIS_KEY}
scopes:
- productservice
- orderservice
EOF

az containerapp env dapr-component set \
    --resource-group $RESOURCE_GROUP \
    --name "${NAME_PREFIX}-env" \
    --dapr-component-name statestore \
    --yaml statestore-temp.yaml

rm statestore-temp.yaml
echo "✅ Dapr State Store configured"

# Create Dapr PubSub Component
echo "📬 Creating Dapr PubSub..."
cat > pubsub-temp.yaml << EOF
componentType: pubsub.redis
version: v1
metadata:
- name: redisHost
  value: ${REDIS_HOST}:6380
- name: redisPassword
  secretRef: redis-password
- name: enableTLS
  value: "true"
secrets:
- name: redis-password
  value: ${REDIS_KEY}
scopes:
- productservice
- orderservice
EOF

az containerapp env dapr-component set \
    --resource-group $RESOURCE_GROUP \
    --name "${NAME_PREFIX}-env" \
    --dapr-component-name product-pubsub \
    --yaml pubsub-temp.yaml

rm pubsub-temp.yaml
echo "✅ Dapr PubSub configured"

echo ""
echo "🎉 Manual resource creation complete!"
echo "======================================"
echo "✅ Container Registry: ${NAME_PREFIX}registry.azurecr.io"
echo "✅ Container Apps Environment: ${NAME_PREFIX}-env"
echo "✅ Redis Cache: ${NAME_PREFIX}redis"
echo "✅ Log Analytics: ${NAME_PREFIX}logs"
echo "✅ Application Insights: ${NAME_PREFIX}insights"
echo ""
echo "🔧 Next steps:"
echo "1. Build and push container images"
echo "2. Create container apps"
echo ""
echo "Run: az acr login --name ${NAME_PREFIX}registry"
echo "Then: ./scripts/build-images.sh --registry ${NAME_PREFIX}registry.azurecr.io --tag latest --push"