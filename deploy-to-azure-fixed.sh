#!/bin/bash

# Robust Azure Deployment Script for Dapr Microservices
# This script handles deployment errors and provides better error handling

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
RESOURCE_GROUP=""
LOCATION="eastus2"
NAME_PREFIX="ajdaprmicro"

# Function to display usage
show_help() {
    cat << EOF
Robust Azure Deployment for Dapr Microservices

Usage: $0 --resource-group <name> [OPTIONS]

REQUIRED:
    -g, --resource-group NAME  Azure Resource Group name

OPTIONS:
    -l, --location LOCATION    Azure region (default: eastus2)
    -p, --prefix PREFIX        Name prefix for resources (default: ajdaprmicro)
    -h, --help                 Display this help message

EXAMPLES:
    $0 -g aj-microservices-rg
    $0 --resource-group myapp-rg --location westus2 --prefix myapp

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -p|--prefix)
            NAME_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" ]]; then
    echo -e "${RED}❌ Resource group is required${NC}"
    show_help
    exit 1
fi

# Set resource names
REGISTRY_NAME="${NAME_PREFIX}registry"
ENVIRONMENT_NAME="${NAME_PREFIX}-env"

echo -e "${BLUE}🚀 Deploying Dapr Microservices to Azure${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "${YELLOW}📋 Configuration:${NC}"
echo -e "   Resource Group: $RESOURCE_GROUP"
echo -e "   Location: $LOCATION" 
echo -e "   Name Prefix: $NAME_PREFIX"
echo -e "   Registry: $REGISTRY_NAME"
echo ""

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed${NC}"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged in to Azure. Please run 'az login'${NC}"
    exit 1
fi

if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ Podman is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites met${NC}"

# Create resource group
echo -e "${YELLOW}🏗️  Creating resource group (if it doesn't exist)...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo -e "${GREEN}✅ Resource group ready${NC}"

# Step 1: Deploy infrastructure
echo -e "${YELLOW}🏗️  Deploying infrastructure...${NC}"
INFRA_DEPLOYMENT_NAME="infra-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file infrastructure/azure/main.bicep \
    --name "$INFRA_DEPLOYMENT_NAME" \
    --parameters \
        namePrefix="$NAME_PREFIX" \
        location="$LOCATION" \
        environmentName="$ENVIRONMENT_NAME" \
        containerRegistryName="$REGISTRY_NAME" \
    --output none

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Infrastructure deployed${NC}"
else
    echo -e "${RED}❌ Infrastructure deployment failed${NC}"
    exit 1
fi

# Wait a moment for resources to be fully available
echo -e "${YELLOW}⏳ Waiting for resources to be ready...${NC}"
sleep 30

# Get registry server with retry logic
echo -e "${YELLOW}🔍 Getting container registry details...${NC}"
REGISTRY_SERVER=""
RETRY_COUNT=0
MAX_RETRIES=5

while [[ -z "$REGISTRY_SERVER" && $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    REGISTRY_SERVER=$(az acr show \
        --name "$REGISTRY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query 'loginServer' \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$REGISTRY_SERVER" ]]; then
        echo -e "${YELLOW}⏳ Waiting for registry to be available... (attempt $((RETRY_COUNT + 1))/${MAX_RETRIES})${NC}"
        sleep 10
        ((RETRY_COUNT++))
    fi
done

if [[ -z "$REGISTRY_SERVER" ]]; then
    echo -e "${RED}❌ Could not get registry server after ${MAX_RETRIES} attempts${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Registry server: $REGISTRY_SERVER${NC}"

# Step 2: Login to ACR and build images
echo -e "${YELLOW}🔐 Logging into Azure Container Registry...${NC}"
az acr login --name "$REGISTRY_NAME"

echo -e "${YELLOW}🐳 Building and pushing images...${NC}"
./scripts/build-images.sh --registry "$REGISTRY_SERVER" --tag "latest" --push

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Images pushed to registry${NC}"
else
    echo -e "${RED}❌ Image build/push failed${NC}"
    exit 1
fi

# Step 3: Deploy applications with actual images
echo -e "${YELLOW}🚀 Deploying applications with container images...${NC}"
PRODUCT_IMAGE="$REGISTRY_SERVER/productservice:latest"
ORDER_IMAGE="$REGISTRY_SERVER/orderservice:latest"

APPS_DEPLOYMENT_NAME="apps-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file infrastructure/azure/main.bicep \
    --name "$APPS_DEPLOYMENT_NAME" \
    --parameters \
        namePrefix="$NAME_PREFIX" \
        location="$LOCATION" \
        environmentName="$ENVIRONMENT_NAME" \
        containerRegistryName="$REGISTRY_NAME" \
        productServiceImage="$PRODUCT_IMAGE" \
        orderServiceImage="$ORDER_IMAGE" \
    --output none

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Applications deployed${NC}"
else
    echo -e "${RED}❌ Application deployment failed${NC}"
    exit 1
fi

# Step 4: Get service URLs with retry logic
echo -e "${YELLOW}🔍 Getting service URLs...${NC}"
sleep 15  # Give apps time to start

PRODUCT_URL=""
ORDER_URL=""

# Try to get URLs with retries
for i in {1..3}; do
    echo -e "${YELLOW}⏳ Getting service URLs (attempt $i/3)...${NC}"
    
    PRODUCT_URL=$(az containerapp show \
        --name "${NAME_PREFIX}-productservice" \
        --resource-group "$RESOURCE_GROUP" \
        --query 'properties.configuration.ingress.fqdn' \
        --output tsv 2>/dev/null || echo "")
    
    ORDER_URL=$(az containerapp show \
        --name "${NAME_PREFIX}-orderservice" \
        --resource-group "$RESOURCE_GROUP" \
        --query 'properties.configuration.ingress.fqdn' \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -n "$PRODUCT_URL" && -n "$ORDER_URL" ]]; then
        break
    fi
    
    sleep 10
done

# Display results
echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo -e "${GREEN}========================${NC}"
echo -e "${GREEN}✅ Resource Group: $RESOURCE_GROUP${NC}"
echo -e "${GREEN}✅ Container Registry: $REGISTRY_SERVER${NC}"
echo -e "${GREEN}✅ Container Apps Environment: $ENVIRONMENT_NAME${NC}"

if [[ -n "$PRODUCT_URL" ]]; then
    echo -e "${GREEN}🌐 ProductService: https://$PRODUCT_URL${NC}"
else
    echo -e "${YELLOW}⚠️  ProductService URL not available yet${NC}"
fi

if [[ -n "$ORDER_URL" ]]; then
    echo -e "${GREEN}🌐 OrderService: https://$ORDER_URL${NC}"
else
    echo -e "${YELLOW}⚠️  OrderService URL not available yet${NC}"
fi

# Manual way to get URLs if automatic detection failed
if [[ -z "$PRODUCT_URL" || -z "$ORDER_URL" ]]; then
    echo ""
    echo -e "${BLUE}🔧 Get service URLs manually:${NC}"
    echo -e "   az containerapp show --name ${NAME_PREFIX}-productservice --resource-group $RESOURCE_GROUP --query 'properties.configuration.ingress.fqdn' --output tsv"
    echo -e "   az containerapp show --name ${NAME_PREFIX}-orderservice --resource-group $RESOURCE_GROUP --query 'properties.configuration.ingress.fqdn' --output tsv"
fi

echo ""
echo -e "${BLUE}🧪 Test your deployment:${NC}"
echo -e "   # Health checks"
echo -e "   curl https://\$PRODUCT_URL/health"
echo -e "   curl https://\$ORDER_URL/health"
echo -e ""
echo -e "   # API endpoints"  
echo -e "   curl https://\$PRODUCT_URL/api/products"
echo -e "   curl https://\$ORDER_URL/api/orders"

echo ""
echo -e "${BLUE}🔍 Monitor your deployment:${NC}"
echo -e "   az containerapp logs show --name ${NAME_PREFIX}-productservice --resource-group $RESOURCE_GROUP --follow"
echo -e "   az containerapp logs show --name ${NAME_PREFIX}-orderservice --resource-group $RESOURCE_GROUP --follow"

echo ""
echo -e "${GREEN}🎯 Deployment successful! Your microservices are running in Azure Container Apps.${NC}"