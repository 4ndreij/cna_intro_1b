#!/bin/bash

# Podman Build Script for Microservices
# This script builds container images using Podman with best practices

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
REGISTRY=""
TAG="latest"
BUILD_CONTEXT="."
PUSH_IMAGES="false"

# Function to display usage
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Build container images for the Dapr microservices using Podman

OPTIONS:
    -r, --registry REGISTRY     Container registry (e.g., myregistry.azurecr.io)
    -t, --tag TAG              Image tag (default: latest)
    -p, --push                 Push images to registry after building
    -h, --help                 Display this help message

EXAMPLES:
    $0                         # Build images locally
    $0 -r myregistry.azurecr.io -t v1.0.0 -p
    $0 --registry localhost:5000 --tag dev --push

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -p|--push)
            PUSH_IMAGES="true"
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

# Set image names
if [[ -n "$REGISTRY" ]]; then
    PRODUCT_IMAGE="$REGISTRY/productservice:$TAG"
    ORDER_IMAGE="$REGISTRY/orderservice:$TAG"
else
    PRODUCT_IMAGE="productservice:$TAG"
    ORDER_IMAGE="orderservice:$TAG"
fi

echo -e "${BLUE}🐳 Starting container image builds with Podman${NC}"
echo -e "${BLUE}===============================================${NC}"

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ Podman is not installed or not in PATH${NC}"
    echo -e "${YELLOW}💡 Install Podman: https://podman.io/getting-started/installation${NC}"
    exit 1
fi

# Check if we're in the correct directory
if [[ ! -f "DaprMicroservices.sln" ]]; then
    echo -e "${RED}❌ Please run this script from the solution root directory${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Build Configuration:${NC}"
echo -e "   Product Service: ${PRODUCT_IMAGE}"
echo -e "   Order Service:   ${ORDER_IMAGE}"
echo -e "   Push to registry: ${PUSH_IMAGES}"
echo ""

# Build ProductService image
echo -e "${YELLOW}🔨 Building ProductService image...${NC}"
if podman build \
    -f infrastructure/docker/ProductService.Dockerfile \
    -t "$PRODUCT_IMAGE" \
    --platform linux/amd64 \
    --label "org.opencontainers.image.source=https://github.com/your-repo/dapr-microservices" \
    --label "org.opencontainers.image.version=$TAG" \
    --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$BUILD_CONTEXT"; then
    echo -e "${GREEN}✅ ProductService image built successfully${NC}"
else
    echo -e "${RED}❌ Failed to build ProductService image${NC}"
    exit 1
fi

# Build OrderService image
echo -e "${YELLOW}🔨 Building OrderService image...${NC}"
if podman build \
    -f infrastructure/docker/OrderService.Dockerfile \
    -t "$ORDER_IMAGE" \
    --platform linux/amd64 \
    --label "org.opencontainers.image.source=https://github.com/your-repo/dapr-microservices" \
    --label "org.opencontainers.image.version=$TAG" \
    --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$BUILD_CONTEXT"; then
    echo -e "${GREEN}✅ OrderService image built successfully${NC}"
else
    echo -e "${RED}❌ Failed to build OrderService image${NC}"
    exit 1
fi

# Push images if requested
if [[ "$PUSH_IMAGES" == "true" ]]; then
    if [[ -z "$REGISTRY" ]]; then
        echo -e "${RED}❌ Registry must be specified when pushing images${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}🚀 Pushing images to registry...${NC}"
    
    if podman push "$PRODUCT_IMAGE"; then
        echo -e "${GREEN}✅ ProductService image pushed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to push ProductService image${NC}"
        exit 1
    fi
    
    if podman push "$ORDER_IMAGE"; then
        echo -e "${GREEN}✅ OrderService image pushed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to push OrderService image${NC}"
        exit 1
    fi
fi

# Display summary
echo ""
echo -e "${GREEN}🎉 Build Summary${NC}"
echo -e "${GREEN}===============${NC}"
echo -e "${GREEN}✅ ProductService: ${PRODUCT_IMAGE}${NC}"
echo -e "${GREEN}✅ OrderService:   ${ORDER_IMAGE}${NC}"

if [[ "$PUSH_IMAGES" == "true" ]]; then
    echo -e "${GREEN}✅ Images pushed to registry${NC}"
fi

# Show image details
echo ""
echo -e "${BLUE}📊 Image Details:${NC}"
podman images --format "table {{.Repository}}:{{.Tag}} {{.Size}} {{.Created}}" | grep -E "(productservice|orderservice|REPOSITORY)"

echo ""
echo -e "${GREEN}🚀 Next steps:${NC}"
echo -e "   1. Test images locally: ./scripts/run-containers.sh"
echo -e "   2. Deploy to staging/production"
echo -e "   3. Update deployment manifests with new image tags"
