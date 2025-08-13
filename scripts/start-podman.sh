#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 Starting Dapr Microservices with Podman${NC}"
echo "============================================="

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ Podman is not installed. Please install it first.${NC}"
    echo "Visit: https://podman.io/getting-started/installation"
    exit 1
fi

# Check if podman-compose is available
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
elif command -v docker-compose &> /dev/null && podman system service --version &> /dev/null; then
    echo -e "${YELLOW}⚠️  Using docker-compose with Podman socket${NC}"
    COMPOSE_CMD="docker-compose"
    
    # Start Podman socket if not running
    if ! podman system service --version &> /dev/null; then
        echo -e "${YELLOW}🔌 Starting Podman socket...${NC}"
        podman system service -t 0 unix:///tmp/podman.sock &
        export DOCKER_HOST=unix:///tmp/podman.sock
        sleep 3
    fi
else
    echo -e "${RED}❌ Neither podman-compose nor docker-compose with Podman is available.${NC}"
    echo "Please install podman-compose or docker-compose"
    exit 1
fi

echo -e "${GREEN}✅ Using compose command: $COMPOSE_CMD${NC}"

# Build and start services
echo -e "${BLUE}🔨 Building and starting services...${NC}"
$COMPOSE_CMD -f docker-compose.yml up --build -d

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to start services with Podman${NC}"
    exit 1
fi

# Wait for services to be ready
echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
sleep 15

# Check service health
echo -e "${BLUE}🔍 Checking service health...${NC}"

# Check ProductService
if curl -s http://localhost:5001/health > /dev/null; then
    echo -e "${GREEN}✅ ProductService is healthy${NC}"
else
    echo -e "${RED}❌ ProductService health check failed${NC}"
fi

# Check OrderService
if curl -s http://localhost:5002/health > /dev/null; then
    echo -e "${GREEN}✅ OrderService is healthy${NC}"
else
    echo -e "${RED}❌ OrderService health check failed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Podman environment is ready!${NC}"
echo ""
echo -e "${BLUE}📋 Service Information:${NC}"
echo "================================="
echo -e "ProductService: ${YELLOW}http://localhost:5001${NC}"
echo -e "OrderService: ${YELLOW}http://localhost:5002${NC}"
echo -e "Redis: ${YELLOW}localhost:6379${NC}"
echo -e "Zipkin (Tracing): ${YELLOW}http://localhost:9411${NC}"
echo ""
echo -e "${BLUE}🛠️  Commands:${NC}"
echo "================================="
echo "View logs: $COMPOSE_CMD logs -f [service_name]"
echo "Stop services: ./scripts/stop-podman.sh"
echo "Test APIs: ./scripts/test-apis.sh"
echo "Container status: podman ps"
