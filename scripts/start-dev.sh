#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Dapr Microservices Development Environment${NC}"
echo "=================================================="

# Check if Dapr CLI is installed
if ! command -v dapr &> /dev/null; then
    echo -e "${RED}❌ Dapr CLI is not installed. Please install it first.${NC}"
    echo "Visit: https://docs.dapr.io/getting-started/install-dapr-cli/"
    exit 1
fi

# Check if .NET 8 is installed
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}❌ .NET SDK is not installed. Please install .NET 8.${NC}"
    exit 1
fi

# Check if Redis is running (for local development)
if ! redis-cli ping &> /dev/null; then
    echo -e "${YELLOW}⚠️  Redis is not running. Starting Redis with Docker...${NC}"
    docker run -d -p 6379:6379 --name dapr-redis redis:alpine || {
        echo -e "${RED}❌ Failed to start Redis. Please ensure Docker is installed and running.${NC}"
        exit 1
    }
    
    # Wait for Redis to be ready
    echo -e "${YELLOW}⏳ Waiting for Redis to be ready...${NC}"
    sleep 3
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Build the solution
echo -e "${BLUE}🔨 Building the solution...${NC}"
dotnet build DaprMicroservices.sln --configuration Debug

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed. Please fix compilation errors.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Solution built successfully${NC}"

# Start services with Dapr
echo -e "${BLUE}🌟 Starting services with Dapr...${NC}"

# Start ProductService
echo -e "${YELLOW}📦 Starting ProductService on port 5001...${NC}"
dapr run \
    --app-id productservice \
    --app-port 5001 \
    --dapr-http-port 3501 \
    --dapr-grpc-port 3601 \
    --components-path ./infrastructure/dapr \
    --config ./infrastructure/dapr/config.yaml \
    --log-level info \
    -- dotnet run --project src/ProductService --urls "http://localhost:5001" &

# Wait a bit for ProductService to start
sleep 5

# Start OrderService  
echo -e "${YELLOW}🛒 Starting OrderService on port 5002...${NC}"
dapr run \
    --app-id orderservice \
    --app-port 5002 \
    --dapr-http-port 3502 \
    --dapr-grpc-port 3602 \
    --components-path ./infrastructure/dapr \
    --config ./infrastructure/dapr/config.yaml \
    --log-level info \
    -- dotnet run --project src/OrderService --urls "http://localhost:5002" &

# Wait for services to start
echo -e "${YELLOW}⏳ Waiting for services to initialize...${NC}"
sleep 10

# Check if services are running
echo -e "${BLUE}🔍 Checking service health...${NC}"

# Check ProductService health
if curl -s http://localhost:5001/health > /dev/null; then
    echo -e "${GREEN}✅ ProductService is healthy (http://localhost:5001)${NC}"
else
    echo -e "${RED}❌ ProductService health check failed${NC}"
fi

# Check OrderService health
if curl -s http://localhost:5002/health > /dev/null; then
    echo -e "${GREEN}✅ OrderService is healthy (http://localhost:5002)${NC}"
else
    echo -e "${RED}❌ OrderService health check failed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Development environment is ready!${NC}"
echo ""
echo -e "${BLUE}📋 Service Information:${NC}"
echo "================================="
echo -e "ProductService API: ${YELLOW}http://localhost:5001${NC}"
echo -e "ProductService Swagger: ${YELLOW}http://localhost:5001${NC}"
echo -e "ProductService Dapr: ${YELLOW}http://localhost:3501${NC}"
echo ""
echo -e "OrderService API: ${YELLOW}http://localhost:5002${NC}"
echo -e "OrderService Swagger: ${YELLOW}http://localhost:5002${NC}"
echo -e "OrderService Dapr: ${YELLOW}http://localhost:3502${NC}"
echo ""
echo -e "${BLUE}🛠️  Development Commands:${NC}"
echo "================================="
echo "Test APIs: ./scripts/test-apis.sh"
echo "Stop services: ./scripts/stop-dev.sh"
echo "View logs: ./scripts/logs.sh"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"

# Wait for user interrupt
trap 'echo -e "\n${YELLOW}🛑 Shutting down services...${NC}"; ./scripts/stop-dev.sh; exit 0' SIGINT

# Keep script running
while true; do
    sleep 1
done
