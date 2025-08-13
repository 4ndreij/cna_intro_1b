#!/bin/bash

# Azure Deployment Script for Dapr Microservices
# This script deploys the infrastructure and applications to Azure Container Apps

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
SUBSCRIPTION=""
NAME_PREFIX="daprmicro"
DEPLOY_INFRA="true"
BUILD_IMAGES="true"
DEPLOY_APPS="true"

# Function to display usage
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Dapr microservices to Azure Container Apps

OPTIONS:
    -g, --resource-group NAME  Azure Resource Group name (required)
    -l, --location LOCATION    Azure region (default: eastus2)  
    -s, --subscription ID      Azure subscription ID
    -p, --prefix PREFIX        Name prefix for resources (default: daprmicro)
    --skip-infra               Skip infrastructure deployment
    --skip-build               Skip container image build
    --skip-deploy              Skip application deployment
    -h, --help                 Display this help message

EXAMPLES:
    $0 -g myresourcegroup -l eastus2
    $0 --resource-group myresourcegroup --prefix myapp --skip-build

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
        -s|--subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        -p|--prefix)
            NAME_PREFIX="$2"
            shift 2
            ;;
        --skip-infra)
            DEPLOY_INFRA="false"
            shift
            ;;
        --skip-build)
            BUILD_IMAGES="false"
            shift
            ;;
        --skip-deploy)
            DEPLOY_APPS="false"
            shift
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

echo -e "${BLUE}☁️  Starting Azure deployment${NC}"
echo -e "${BLUE}============================${NC}"
echo -e "${YELLOW}📋 Configuration:${NC}"
echo -e "   Resource Group: $RESOURCE_GROUP"
echo -e "   Location: $LOCATION"
echo -e "   Name Prefix: $NAME_PREFIX"
echo -e "   Registry: $REGISTRY_NAME"
echo -e "   Environment: $ENVIRONMENT_NAME"
echo ""

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed${NC}"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged in to Azure. Please run 'az login'${NC}"
    exit 1
fi

# Set subscription if provided
if [[ -n "$SUBSCRIPTION" ]]; then
    echo -e "${YELLOW}🔧 Setting subscription: $SUBSCRIPTION${NC}"
    az account set --subscription "$SUBSCRIPTION"
fi

# Create resource group if it doesn't exist
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${YELLOW}🏗️  Creating resource group: $RESOURCE_GROUP${NC}"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
else
    echo -e "${GREEN}✅ Resource group exists: $RESOURCE_GROUP${NC}"
fi

# Deploy infrastructure
if [[ "$DEPLOY_INFRA" == "true" ]]; then
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
            containerRegistryName="$REGISTRY_NAME"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
    else
        echo -e "${RED}❌ Infrastructure deployment failed${NC}"
        exit 1
    fi
    
    # Get outputs
    REGISTRY_SERVER=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query 'properties.outputs.containerRegistryLoginServer.value' \
        --output tsv)
    
    echo -e "${GREEN}📋 Registry Server: $REGISTRY_SERVER${NC}"
else
    echo -e "${YELLOW}⏭️  Skipping infrastructure deployment${NC}"
    
    # Get existing registry server
    REGISTRY_SERVER=$(az acr show \
        --name "$REGISTRY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query 'loginServer' \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$REGISTRY_SERVER" ]]; then
        echo -e "${RED}❌ Could not find container registry. Deploy infrastructure first.${NC}"
        exit 1
    fi
fi

# Build and push container images
if [[ "$BUILD_IMAGES" == "true" ]]; then
    echo -e "${YELLOW}🐳 Building and pushing container images...${NC}"
    
    # Login to ACR
    az acr login --name "$REGISTRY_NAME"
    
    # Build and push using our script
    ./scripts/build-images.sh \
        --registry "$REGISTRY_SERVER" \
        --tag "latest" \
        --push
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Images built and pushed successfully${NC}"
    else
        echo -e "${RED}❌ Image build/push failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⏭️  Skipping image build${NC}"
fi

# Deploy applications with updated images
if [[ "$DEPLOY_APPS" == "true" ]]; then
    echo -e "${YELLOW}🚀 Updating container apps with new images...${NC}"
    
    PRODUCT_IMAGE="$REGISTRY_SERVER/productservice:latest"
    ORDER_IMAGE="$REGISTRY_SERVER/orderservice:latest"
    
    # Update infrastructure with new image references
    DEPLOYMENT_NAME="dapr-microservices-update-$(date +%Y%m%d-%H%M%S)"
    
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file infrastructure/azure/main.bicep \
        --name "$DEPLOYMENT_NAME" \
        --parameters \
            namePrefix="$NAME_PREFIX" \
            location="$LOCATION" \
            environmentName="$ENVIRONMENT_NAME" \
            containerRegistryName="$REGISTRY_NAME" \
            productServiceImage="$PRODUCT_IMAGE" \
            orderServiceImage="$ORDER_IMAGE"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Applications deployed successfully${NC}"
        
        # Get service URLs
        PRODUCT_URL=$(az deployment group show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$DEPLOYMENT_NAME" \
            --query 'properties.outputs.productServiceUrl.value' \
            --output tsv)
        
        ORDER_URL=$(az deployment group show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$DEPLOYMENT_NAME" \
            --query 'properties.outputs.orderServiceUrl.value' \
            --output tsv)
        
        echo -e "${GREEN}🌐 Service URLs:${NC}"
        echo -e "   ProductService: https://$PRODUCT_URL"
        echo -e "   OrderService: https://$ORDER_URL"
    else
        echo -e "${RED}❌ Application deployment failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⏭️  Skipping application deployment${NC}"
fi

# Display summary
echo ""
echo -e "${GREEN}🎉 Deployment Summary${NC}"
echo -e "${GREEN}=====================${NC}"
echo -e "${GREEN}✅ Resource Group: $RESOURCE_GROUP${NC}"
echo -e "${GREEN}✅ Container Registry: $REGISTRY_SERVER${NC}"
echo -e "${GREEN}✅ Container Apps Environment: $ENVIRONMENT_NAME${NC}"

if [[ "$DEPLOY_APPS" == "true" ]]; then
    echo -e "${GREEN}✅ ProductService: https://$PRODUCT_URL${NC}"
    echo -e "${GREEN}✅ OrderService: https://$ORDER_URL${NC}"
fi

echo ""
echo -e "${BLUE}🛠️  Next steps:${NC}"
echo -e "   1. Test the deployed services"
echo -e "   2. Monitor logs in Application Insights"
echo -e "   3. Set up CI/CD pipelines"
echo -e "   4. Configure custom domains (optional)"
