#!/bin/bash

# Container Build and Push Script
# Builds and pushes container images to Azure Container Registry

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
REGISTRY_NAME="$2"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DEPLOY_DIR")"

echo -e "${CYAN}🐳 Container Build and Push${NC}"
echo -e "${CYAN}=========================${NC}"
echo -e "   Resource Group: $RESOURCE_GROUP"
echo -e "   Registry: $REGISTRY_NAME"
echo -e "   Project Root: $PROJECT_ROOT"
echo ""

# Get registry URL and credentials
echo -e "${YELLOW}🔑 Getting Azure Container Registry credentials...${NC}"
REGISTRY_URL=$(az acr show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer --output tsv)

# Get registry credentials
REGISTRY_USERNAME=$(az acr credential show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query username --output tsv)
REGISTRY_PASSWORD=$(az acr credential show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query passwords[0].value --output tsv)

# Login using podman
echo -e "${YELLOW}🔑 Logging into registry with podman...${NC}"
podman login "$REGISTRY_URL" --username "$REGISTRY_USERNAME" --password "$REGISTRY_PASSWORD"
echo -e "${GREEN}✅ Logged into registry: $REGISTRY_URL${NC}"

# Build ProductService
echo -e "${YELLOW}🔨 Building ProductService...${NC}"
cd "$PROJECT_ROOT/src/ProductService"

podman build -f "$PROJECT_ROOT/infrastructure/docker/ProductService.Dockerfile" -t "productservice:latest" "$PROJECT_ROOT"
podman tag "productservice:latest" "$REGISTRY_URL/productservice:latest"

echo -e "${YELLOW}⬆️ Pushing ProductService...${NC}"
podman push "$REGISTRY_URL/productservice:latest"
echo -e "${GREEN}✅ ProductService image pushed${NC}"

# Build OrderService
echo -e "${YELLOW}🔨 Building OrderService...${NC}"
cd "$PROJECT_ROOT/src/OrderService"

podman build -f "$PROJECT_ROOT/infrastructure/docker/OrderService.Dockerfile" -t "orderservice:latest" "$PROJECT_ROOT"
podman tag "orderservice:latest" "$REGISTRY_URL/orderservice:latest"

echo -e "${YELLOW}⬆️ Pushing OrderService...${NC}"
podman push "$REGISTRY_URL/orderservice:latest"
echo -e "${GREEN}✅ OrderService image pushed${NC}"

# List pushed images
echo -e "${YELLOW}📋 Registry contents:${NC}"
az acr repository list --name "$REGISTRY_NAME" --output table

echo ""
echo -e "${GREEN}🎉 All images built and pushed successfully!${NC}"
echo -e "${GREEN}   Registry: $REGISTRY_URL${NC}"
echo -e "${GREEN}   Images: productservice:latest, orderservice:latest${NC}"