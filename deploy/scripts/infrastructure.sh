#!/bin/bash

# Infrastructure Deployment Script
# Creates Azure resources for Container Apps deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parameters
RESOURCE_GROUP="$1"
LOCATION="$2"
PREFIX="$3"
ENVIRONMENT_NAME="$4"

# Resource names (remove dashes for registry name)
REGISTRY_NAME="${PREFIX//[-]/}registry"
LOG_ANALYTICS_NAME="${PREFIX}-logs"
APP_INSIGHTS_NAME="${PREFIX}-insights"

echo -e "${CYAN}🏗️ Infrastructure Deployment${NC}"
echo -e "${CYAN}===========================${NC}"
echo -e "   Resource Group: $RESOURCE_GROUP"
echo -e "   Location: $LOCATION"
echo -e "   Prefix: $PREFIX"
echo -e "   Environment: $ENVIRONMENT_NAME"
echo ""

# Create Azure Container Registry
echo -e "${YELLOW}📦 Creating Container Registry...${NC}"
az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$REGISTRY_NAME" \
    --sku Basic \
    --admin-enabled true \
    --location "$LOCATION" \
    --output none

echo -e "${GREEN}✅ Container Registry created: $REGISTRY_NAME${NC}"

# Create Log Analytics Workspace
echo -e "${YELLOW}📊 Creating Log Analytics Workspace...${NC}"
az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_ANALYTICS_NAME" \
    --location "$LOCATION" \
    --sku PerGB2018 \
    --retention-time 30 \
    --output none

# Get Log Analytics workspace ID and key
LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_ANALYTICS_NAME" \
    --query customerId \
    --output tsv)

LOG_ANALYTICS_KEY=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_ANALYTICS_NAME" \
    --query primarySharedKey \
    --output tsv)

echo -e "${GREEN}✅ Log Analytics Workspace created: $LOG_ANALYTICS_NAME${NC}"

# Create Application Insights
echo -e "${YELLOW}📈 Creating Application Insights...${NC}"

# Check if Application Insights extension is installed
if ! az extension list --output tsv | grep -q application-insights; then
    echo -e "${YELLOW}📦 Installing Application Insights extension...${NC}"
    az extension add --name application-insights --allow-preview
fi

# Create Application Insights with correct workspace reference
az monitor app-insights component create \
    --app "$APP_INSIGHTS_NAME" \
    --location "$LOCATION" \
    --resource-group "$RESOURCE_GROUP" \
    --workspace "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$LOG_ANALYTICS_NAME" \
    --output none

# Get Application Insights connection string
APP_INSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show \
    --app "$APP_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query connectionString \
    --output tsv)

echo -e "${GREEN}✅ Application Insights created: $APP_INSIGHTS_NAME${NC}"

# Get Application Insights instrumentation key
APP_INSIGHTS_INSTRUMENTATION_KEY=$(az monitor app-insights component show \
    --app "$APP_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query instrumentationKey \
    --output tsv)

echo -e "${BLUE}📊 Application Insights Key: $APP_INSIGHTS_INSTRUMENTATION_KEY${NC}"

# Create Container Apps Environment
echo -e "${YELLOW}🏗️ Creating Container Apps Environment...${NC}"
az containerapp env create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ENVIRONMENT_NAME" \
    --location "$LOCATION" \
    --logs-workspace-id "$LOG_ANALYTICS_WORKSPACE_ID" \
    --logs-workspace-key "$LOG_ANALYTICS_KEY" \
    --dapr-instrumentation-key "$APP_INSIGHTS_INSTRUMENTATION_KEY" \
    --enable-workload-profiles false \
    --output none

# Enable Dapr (skip default configuration component as it's causing issues)
echo -e "${YELLOW}⚙️ Dapr enabled with Container Apps Environment${NC}"

echo -e "${GREEN}✅ Container Apps Environment created: $ENVIRONMENT_NAME${NC}"

# Display infrastructure summary
echo ""
echo -e "${GREEN}🎉 Infrastructure Deployment Complete!${NC}"
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}✅ Container Registry: $REGISTRY_NAME${NC}"
echo -e "${GREEN}✅ Log Analytics: $LOG_ANALYTICS_NAME${NC}"
echo -e "${GREEN}✅ Application Insights: $APP_INSIGHTS_NAME${NC}"
echo -e "${GREEN}✅ Container Apps Environment: $ENVIRONMENT_NAME${NC}"
echo ""
echo -e "${BLUE}📋 Resource Details:${NC}"
echo -e "   Registry URL: $(az acr show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer --output tsv)"
echo -e "   Log Analytics ID: $LOG_ANALYTICS_WORKSPACE_ID"
echo -e "   App Insights Connection: ${APP_INSIGHTS_CONNECTION_STRING:0:50}..."
echo ""
echo -e "${CYAN}🚀 Infrastructure is ready for application deployment!${NC}"