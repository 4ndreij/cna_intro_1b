#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Stopping Dapr Microservices Development Environment${NC}"
echo "===================================================="

# Stop Dapr applications
echo -e "${YELLOW}⏹️  Stopping Dapr applications...${NC}"
dapr stop --app-id productservice 2>/dev/null || true
dapr stop --app-id orderservice 2>/dev/null || true

# Kill any remaining dotnet processes for our services
echo -e "${YELLOW}🔄 Cleaning up remaining processes...${NC}"
pkill -f "dotnet.*ProductService" 2>/dev/null || true
pkill -f "dotnet.*OrderService" 2>/dev/null || true

# Stop Redis container if we started it
echo -e "${YELLOW}🗑️  Stopping Redis container...${NC}"
docker stop dapr-redis 2>/dev/null || true
docker rm dapr-redis 2>/dev/null || true

# Clean up any remaining Dapr processes
pkill -f "daprd" 2>/dev/null || true

echo -e "${GREEN}✅ All services stopped successfully${NC}"
echo ""
echo -e "${BLUE}💡 To start the development environment again, run:${NC}"
echo -e "${YELLOW}   ./scripts/start-dev.sh${NC}"
