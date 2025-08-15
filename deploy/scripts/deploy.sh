#!/bin/bash

# Azure Container Apps Deployment Script
# Consolidated deployment based on successful manual deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
RESOURCE_GROUP=""
ENVIRONMENT="dev"
CONFIG_FILE="./config/deployment.yml"
DRY_RUN="false"
SKIP_BUILD="false"
SKIP_INFRASTRUCTURE="false"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DEPLOY_DIR")"

show_help() {
    cat << EOF
Azure Container Apps Deployment Script

USAGE:
    $0 --resource-group <name> [OPTIONS]

REQUIRED:
    -g, --resource-group NAME    Azure Resource Group name

OPTIONS:
    -e, --environment ENV        Environment (dev, staging, production) [default: dev]
    -c, --config FILE           Config file path [default: ./config/deployment.yml]
    --dry-run                   Show what would be deployed without executing
    --skip-build                Skip container image build and push
    --skip-infrastructure       Skip infrastructure deployment
    -h, --help                  Show this help message

EXAMPLES:
    # Deploy to development
    $0 -g myapp-dev-rg

    # Deploy to production with custom config
    $0 -g myapp-prod-rg --environment production

    # Dry run to see what would be deployed
    $0 -g myapp-dev-rg --dry-run

    # Skip build if images are already pushed
    $0 -g myapp-dev-rg --skip-build

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --skip-build)
            SKIP_BUILD="true"
            shift
            ;;
        --skip-infrastructure)
            SKIP_INFRASTRUCTURE="true"
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

# Load configuration (simplified YAML parsing)
load_config() {
    local key=$1
    local default=${2:-""}
    
    # Simple YAML value extraction - in production use yq or similar
    local value=$(grep -E "^[[:space:]]*${key}:" "$CONFIG_FILE" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?.*/\1/' | tr -d '"' || echo "$default")
    echo "$value"
}

echo -e "${CYAN}🚀 Azure Container Apps Deployment${NC}"
echo -e "${CYAN}===================================${NC}"

# Load basic configuration
LOCATION=$(load_config "location" "eastus2")
PREFIX=$(load_config "prefix" "daprmicro")

# Add environment suffix for non-dev environments
if [[ "$ENVIRONMENT" != "dev" ]]; then
    PREFIX="${PREFIX}${ENVIRONMENT}"
fi

# Set resource names (remove dashes for registry name)
REGISTRY_NAME="${PREFIX//[-]/}registry"
ENVIRONMENT_NAME="${PREFIX}-env"

echo -e "${YELLOW}📋 Deployment Configuration:${NC}"
echo -e "   Resource Group: $RESOURCE_GROUP"
echo -e "   Environment: $ENVIRONMENT"
echo -e "   Location: $LOCATION"
echo -e "   Prefix: $PREFIX"
echo -e "   Registry: $REGISTRY_NAME"
echo -e "   Container Apps Environment: $ENVIRONMENT_NAME"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - No actual changes will be made${NC}"
fi

echo ""

# Prerequisites check
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found${NC}"
    exit 1
fi

if ! command -v podman &> /dev/null && [[ "$SKIP_BUILD" != "true" ]]; then
    echo -e "${RED}❌ Podman not found${NC}"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged into Azure. Run 'az login'${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Exit if dry run
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${GREEN}🔍 Dry run complete. Would deploy the configuration shown above.${NC}"
    exit 0
fi

# Create resource group
echo -e "${YELLOW}🏗️ Creating resource group...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo -e "${GREEN}✅ Resource group ready${NC}"

# Deploy infrastructure
if [[ "$SKIP_INFRASTRUCTURE" != "true" ]]; then
    echo -e "${YELLOW}🏗️ Deploying infrastructure...${NC}"
    "$SCRIPT_DIR/infrastructure.sh" "$RESOURCE_GROUP" "$LOCATION" "$PREFIX" "$ENVIRONMENT_NAME"
    echo -e "${GREEN}✅ Infrastructure deployed${NC}"
else
    echo -e "${YELLOW}⏭️ Skipping infrastructure deployment${NC}"
fi

# Build and push images
if [[ "$SKIP_BUILD" != "true" ]]; then
    echo -e "${YELLOW}🐳 Building and pushing images...${NC}"
    "$SCRIPT_DIR/build-and-push.sh" "$RESOURCE_GROUP" "$REGISTRY_NAME"
    echo -e "${GREEN}✅ Images built and pushed${NC}"
else
    echo -e "${YELLOW}⏭️ Skipping image build${NC}"
fi

# Deploy applications
echo -e "${YELLOW}🚀 Deploying applications...${NC}"

# Get registry URL
REGISTRY_URL=$(az acr show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer --output tsv)

# Deploy Redis
echo -e "${YELLOW}📦 Deploying Redis...${NC}"
az containerapp create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${PREFIX}-redis" \
    --environment "$ENVIRONMENT_NAME" \
    --image redis:7-alpine \
    --target-port 6379 \
    --ingress internal \
    --transport tcp \
    --min-replicas 1 \
    --max-replicas 1 \
    --cpu 0.25 \
    --memory 0.5Gi \
    --output none

# Configure Dapr components
echo -e "${YELLOW}🔧 Configuring Dapr components...${NC}"

REDIS_HOST="${PREFIX}-redis:6379"

# Create state store component
echo -e "${YELLOW}📦 Creating Dapr state store component...${NC}"
cat > /tmp/statestore.yml << EOF
componentType: state.redis
version: v1
metadata:
- name: redisHost
  value: "$REDIS_HOST"
scopes:
- productservice
- orderservice
EOF

az containerapp env dapr-component set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ENVIRONMENT_NAME" \
    --dapr-component-name statestore \
    --yaml /tmp/statestore.yml

# Create pub/sub component  
echo -e "${YELLOW}📡 Creating Dapr pub/sub component...${NC}"
cat > /tmp/pubsub.yml << EOF
componentType: pubsub.redis
version: v1
metadata:
- name: redisHost
  value: "$REDIS_HOST"
scopes:
- productservice
- orderservice
EOF

az containerapp env dapr-component set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ENVIRONMENT_NAME" \
    --dapr-component-name product-pubsub \
    --yaml /tmp/pubsub.yml

# Clean up temp files
rm -f /tmp/statestore.yml /tmp/pubsub.yml

# Get registry credentials
REGISTRY_USERNAME=$(az acr credential show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query username --output tsv)
REGISTRY_PASSWORD=$(az acr credential show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query passwords[0].value --output tsv)

# Deploy ProductService
echo -e "${YELLOW}📦 Deploying ProductService...${NC}"
az containerapp create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${PREFIX}-productservice" \
    --environment "$ENVIRONMENT_NAME" \
    --image "${REGISTRY_URL}/productservice:latest" \
    --target-port 8080 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 0.5 \
    --memory 1Gi \
    --enable-dapr \
    --dapr-app-id productservice \
    --dapr-app-port 8080 \
    --registry-server "$REGISTRY_URL" \
    --registry-username "$REGISTRY_USERNAME" \
    --registry-password "$REGISTRY_PASSWORD" \
    --env-vars \
        ASPNETCORE_ENVIRONMENT=Production \
        ASPNETCORE_URLS=http://+:8080 \
    --output none

# Deploy OrderService
echo -e "${YELLOW}📦 Deploying OrderService...${NC}"

az containerapp create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${PREFIX}-orderservice" \
    --environment "$ENVIRONMENT_NAME" \
    --image "${REGISTRY_URL}/orderservice:latest" \
    --target-port 8080 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 0.5 \
    --memory 1Gi \
    --enable-dapr \
    --dapr-app-id orderservice \
    --dapr-app-port 8080 \
    --registry-server "$REGISTRY_URL" \
    --registry-username "$REGISTRY_USERNAME" \
    --registry-password "$REGISTRY_PASSWORD" \
    --env-vars \
        ASPNETCORE_ENVIRONMENT=Production \
        ASPNETCORE_URLS=http://+:8080 \
        "Services__ProductServiceUrl=http://productservice" \
    --output none

echo -e "${GREEN}✅ Applications deployed${NC}"

# Get service URLs
echo -e "${YELLOW}🌐 Retrieving service URLs...${NC}"
PRODUCT_SERVICE_URL=$(az containerapp show \
    --name "${PREFIX}-productservice" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

ORDER_SERVICE_URL=$(az containerapp show \
    --name "${PREFIX}-orderservice" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

# Display results
echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo -e "${GREEN}========================${NC}"
echo -e "${GREEN}✅ Resource Group: $RESOURCE_GROUP${NC}"
echo -e "${GREEN}✅ Environment: $ENVIRONMENT${NC}"
echo -e "${GREEN}✅ Container Registry: $REGISTRY_URL${NC}"
echo -e "${GREEN}✅ Container Apps Environment: $ENVIRONMENT_NAME${NC}"
echo ""
echo -e "${GREEN}🌐 Service URLs:${NC}"
echo -e "${GREEN}   ProductService: https://$PRODUCT_SERVICE_URL${NC}"
echo -e "${GREEN}   OrderService: https://$ORDER_SERVICE_URL${NC}"
echo ""
echo -e "${BLUE}🧪 Test your deployment:${NC}"
echo -e "   curl https://$PRODUCT_SERVICE_URL/health"
echo -e "   curl https://$PRODUCT_SERVICE_URL/api/products"
echo -e "   curl https://$ORDER_SERVICE_URL/health"
echo -e "   curl https://$ORDER_SERVICE_URL/api/orders"
echo ""
echo -e "${BLUE}📊 Monitor your deployment:${NC}"
echo -e "   az containerapp logs show --name ${PREFIX}-productservice --resource-group $RESOURCE_GROUP --follow"
echo -e "   az containerapp logs show --name ${PREFIX}-orderservice --resource-group $RESOURCE_GROUP --follow"
echo ""
echo -e "${GREEN}🎯 Deployment successful! Your microservices are running in Azure Container Apps.${NC}"