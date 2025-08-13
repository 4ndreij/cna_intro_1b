#!/bin/bash

# Quick Azure Deployment Script for Dapr Microservices
# This script provides a streamlined deployment experience

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
NAME_PREFIX="daprmicro"

# Function to display usage
show_help() {
    cat << EOF
Quick Azure Deployment for Dapr Microservices

Usage: $0 --resource-group <name> [OPTIONS]

REQUIRED:
    -g, --resource-group NAME  Azure Resource Group name

OPTIONS:
    -l, --location LOCATION    Azure region (default: eastus2)
    -p, --prefix PREFIX        Name prefix for resources (default: daprmicro)
    -h, --help                 Display this help message

EXAMPLES:
    $0 -g my-microservices-rg
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
echo -e "${YELLOW}🏗️  Creating resource group...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

# Deploy infrastructure
echo -e "${YELLOW}🏗️  Deploying infrastructure...${NC}"
DEPLOYMENT_NAME="dapr-microservices-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file infrastructure/azure/main.bicep \
    --name "$DEPLOYMENT_NAME" \
    --parameters \
        namePrefix="$NAME_PREFIX" \
        location="$LOCATION" \
        environmentName="$ENVIRONMENT_NAME" \
        containerRegistryName="$REGISTRY_NAME" \
    --output table

echo -e "${GREEN}✅ Infrastructure deployed${NC}"

# Get registry server
REGISTRY_SERVER=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query 'properties.outputs.containerRegistryLoginServer.value' \
    --output tsv)

echo -e "${YELLOW}🐳 Building and pushing images...${NC}"

# Login to ACR
az acr login --name "$REGISTRY_NAME"

# Build and push images
./scripts/build-images.sh --registry "$REGISTRY_SERVER" --tag "latest" --push

echo -e "${GREEN}✅ Images pushed to registry${NC}"

# Update deployment with actual images
echo -e "${YELLOW}🚀 Deploying applications...${NC}"
PRODUCT_IMAGE="$REGISTRY_SERVER/productservice:latest"
ORDER_IMAGE="$REGISTRY_SERVER/orderservice:latest"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file infrastructure/azure/main.bicep \
    --name "apps-$(date +%Y%m%d-%H%M%S)" \
    --parameters \
        namePrefix="$NAME_PREFIX" \
        location="$LOCATION" \
        environmentName="$ENVIRONMENT_NAME" \
        containerRegistryName="$REGISTRY_NAME" \
        productServiceImage="$PRODUCT_IMAGE" \
        orderServiceImage="$ORDER_IMAGE" \
    --output table

# Get service URLs
PRODUCT_URL=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "apps-$(date +%Y%m%d-%H%M%S)" \
    --query 'properties.outputs.productServiceUrl.value' \
    --output tsv 2>/dev/null || echo "")

ORDER_URL=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "apps-$(date +%Y%m%d-%H%M%S)" \
    --query 'properties.outputs.orderServiceUrl.value' \
    --output tsv 2>/dev/null || echo "")

# Display results
echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo -e "${GREEN}========================${NC}"
echo -e "${GREEN}✅ Resource Group: $RESOURCE_GROUP${NC}"
echo -e "${GREEN}✅ Container Registry: $REGISTRY_SERVER${NC}"
echo -e "${GREEN}✅ Container Apps Environment: $ENVIRONMENT_NAME${NC}"

if [[ -n "$PRODUCT_URL" ]]; then
    echo -e "${GREEN}🌐 ProductService: https://$PRODUCT_URL${NC}"
fi

if [[ -n "$ORDER_URL" ]]; then
    echo -e "${GREEN}🌐 OrderService: https://$ORDER_URL${NC}"
fi

echo ""
echo -e "${BLUE}🧪 Test your deployment:${NC}"
if [[ -n "$PRODUCT_URL" ]]; then
    echo -e "   curl https://$PRODUCT_URL/health"
    echo -e "   curl https://$PRODUCT_URL/api/products"
fi

if [[ -n "$ORDER_URL" ]]; then
    echo -e "   curl https://$ORDER_URL/health" 
    echo -e "   curl https://$ORDER_URL/api/orders"
fi

echo ""
echo -e "${BLUE}🔍 Monitor your deployment:${NC}"
echo -e "   az containerapp logs show --name ${NAME_PREFIX}-productservice --resource-group $RESOURCE_GROUP --follow"
echo -e "   az containerapp logs show --name ${NAME_PREFIX}-orderservice --resource-group $RESOURCE_GROUP --follow"

echo ""
echo -e "${GREEN}🎯 Deployment successful! Your microservices are running in Azure Container Apps.${NC}"