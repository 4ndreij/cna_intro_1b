#!/bin/bash

# Podman Run Script for Local Development
# This script runs the microservices in containerized environment with Dapr

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK_NAME="dapr-network"
REDIS_CONTAINER="dapr-redis"
PRODUCT_SERVICE="productservice"
ORDER_SERVICE="orderservice"

# Image tags (default to latest, can be overridden)
PRODUCT_IMAGE="${PRODUCT_IMAGE:-productservice:latest}"
ORDER_IMAGE="${ORDER_IMAGE:-orderservice:latest}"

echo -e "${BLUE}🐳 Starting Dapr Microservices with Podman${NC}"
echo -e "${BLUE}==========================================${NC}"

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up containers...${NC}"
    
    # Stop and remove application containers
    podman stop $PRODUCT_SERVICE $ORDER_SERVICE 2>/dev/null || true
    podman rm $PRODUCT_SERVICE $ORDER_SERVICE 2>/dev/null || true
    
    # Stop and remove Dapr sidecars and placement service
    podman stop ${PRODUCT_SERVICE}-dapr ${ORDER_SERVICE}-dapr dapr-placement 2>/dev/null || true
    podman rm ${PRODUCT_SERVICE}-dapr ${ORDER_SERVICE}-dapr dapr-placement 2>/dev/null || true
    
    # Stop Redis (optional - comment out if you want to keep it running)
    # podman stop $REDIS_CONTAINER 2>/dev/null || true
    # podman rm $REDIS_CONTAINER 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Setup signal handlers
trap cleanup EXIT INT TERM

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ Podman is not installed or not in PATH${NC}"
    exit 1
fi

# Check if Dapr CLI is installed
if ! command -v dapr &> /dev/null; then
    echo -e "${RED}❌ Dapr CLI is not installed or not in PATH${NC}"
    exit 1
fi

# Create network if it doesn't exist
if ! podman network exists $NETWORK_NAME 2>/dev/null; then
    echo -e "${YELLOW}🌐 Creating network: $NETWORK_NAME${NC}"
    podman network create $NETWORK_NAME
fi

# Start Redis if not running
if ! podman container exists $REDIS_CONTAINER || ! podman container inspect $REDIS_CONTAINER --format '{{.State.Running}}' | grep -q true; then
    echo -e "${YELLOW}🗄️  Starting Redis container...${NC}"
    podman stop $REDIS_CONTAINER 2>/dev/null || true
    podman rm $REDIS_CONTAINER 2>/dev/null || true
    
    podman run -d \
        --name $REDIS_CONTAINER \
        --network $NETWORK_NAME \
        -p 6379:6379 \
        --health-cmd "redis-cli ping" \
        --health-interval 30s \
        --health-timeout 3s \
        --health-retries 3 \
        docker.io/redis:7-alpine
    
    echo -e "${GREEN}✅ Redis started${NC}"
fi

# Wait for Redis to be healthy
echo -e "${YELLOW}⏳ Waiting for Redis to be ready...${NC}"
until podman healthcheck run $REDIS_CONTAINER &>/dev/null; do
    sleep 1
done
echo -e "${GREEN}✅ Redis is ready${NC}"

# Start Dapr Placement Service
echo -e "${YELLOW}🎯 Starting Dapr Placement Service...${NC}"
podman run -d \
    --name dapr-placement \
    --network $NETWORK_NAME \
    -p 50005:50005 \
    docker.io/daprio/dapr:1.15.0 \
    ./placement \
    --port 50005 \
    --log-level info

echo -e "${GREEN}✅ Placement Service started${NC}"

# Start ProductService
echo -e "${YELLOW}🚀 Starting ProductService...${NC}"
podman run -d \
    --name $PRODUCT_SERVICE \
    --network $NETWORK_NAME \
    -p 5001:8080 \
    -e ASPNETCORE_ENVIRONMENT=Development \
    -e ASPNETCORE_URLS=http://+:8080 \
    -e DAPR_HTTP_ENDPOINT=http://productservice-dapr:3500 \
    -e DAPR_GRPC_ENDPOINT=http://productservice-dapr:50001 \
    -v "$(pwd)/infrastructure/dapr:/dapr/components:ro" \
    $PRODUCT_IMAGE

# Start ProductService Dapr sidecar (on dapr-network, connects to app via network)
echo -e "${YELLOW}🔗 Starting ProductService Dapr sidecar...${NC}"
podman run -d \
    --name ${PRODUCT_SERVICE}-dapr \
    --network $NETWORK_NAME \
    -p 3501:3500 \
    -p 50001:50001 \
    -v "$(pwd)/infrastructure/dapr:/components:ro" \
    docker.io/daprio/daprd:1.15.0 \
    ./daprd \
    --app-id productservice \
    --app-channel-address productservice \
    --app-port 8080 \
    --app-protocol http \
    --dapr-http-port 3500 \
    --dapr-grpc-port 50001 \
    --resources-path /components \
    --placement-host-address dapr-placement:50005 \
    --enable-app-health-check \
    --app-health-check-path /health \
    --log-level info

# Start OrderService
echo -e "${YELLOW}🚀 Starting OrderService...${NC}"
podman run -d \
    --name $ORDER_SERVICE \
    --network $NETWORK_NAME \
    -p 5002:8080 \
    -e ASPNETCORE_ENVIRONMENT=Development \
    -e ASPNETCORE_URLS=http://+:8080 \
    -e Services__ProductServiceUrl=http://${PRODUCT_SERVICE}:8080 \
    -e DAPR_HTTP_ENDPOINT=http://orderservice-dapr:3500 \
    -e DAPR_GRPC_ENDPOINT=http://orderservice-dapr:50001 \
    -v "$(pwd)/infrastructure/dapr:/dapr/components:ro" \
    $ORDER_IMAGE

# Start OrderService Dapr sidecar (on dapr-network, connects to app via network)
echo -e "${YELLOW}🔗 Starting OrderService Dapr sidecar...${NC}"
podman run -d \
    --name ${ORDER_SERVICE}-dapr \
    --network $NETWORK_NAME \
    -p 3502:3500 \
    -p 50002:50001 \
    -v "$(pwd)/infrastructure/dapr:/components:ro" \
    docker.io/daprio/daprd:1.15.0 \
    ./daprd \
    --app-id orderservice \
    --app-channel-address orderservice \
    --app-port 8080 \
    --app-protocol http \
    --dapr-http-port 3500 \
    --dapr-grpc-port 50001 \
    --resources-path /components \
    --placement-host-address dapr-placement:50005 \
    --enable-app-health-check \
    --app-health-check-path /health \
    --log-level info

# Wait for services to start
echo -e "${YELLOW}⏳ Waiting for services to initialize...${NC}"
sleep 15

# Health checks
echo -e "${BLUE}🔍 Checking service health...${NC}"

# Check ProductService
if curl -s http://localhost:5001/health > /dev/null; then
    echo -e "${GREEN}✅ ProductService is healthy (http://localhost:5001)${NC}"
else
    echo -e "${RED}❌ ProductService health check failed${NC}"
fi

# Check OrderService
if curl -s http://localhost:5002/health > /dev/null; then
    echo -e "${GREEN}✅ OrderService is healthy (http://localhost:5002)${NC}"
else
    echo -e "${RED}❌ OrderService health check failed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 All services are running!${NC}"
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}📋 Service Endpoints:${NC}"
echo -e "   ProductService API: http://localhost:5001"
echo -e "   ProductService Swagger: http://localhost:5001"
echo -e "   OrderService API: http://localhost:5002" 
echo -e "   OrderService Swagger: http://localhost:5002"
echo -e "   Redis: localhost:6379"
echo ""
echo -e "${BLUE}🛠️  Management Commands:${NC}"
echo -e "   View logs: podman logs -f [container-name]"
echo -e "   Stop all: podman stop $PRODUCT_SERVICE $ORDER_SERVICE ${PRODUCT_SERVICE}-dapr ${ORDER_SERVICE}-dapr dapr-placement"
echo -e "   View containers: podman ps"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"

# Keep script running and show logs
podman logs -f $PRODUCT_SERVICE &
podman logs -f $ORDER_SERVICE &

# Wait for interrupt
wait
