#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Stopping Dapr Microservices Podman Environment${NC}"
echo "================================================="

# Determine compose command
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    export DOCKER_HOST=unix:///tmp/podman.sock
else
    echo -e "${RED}❌ No compose command available${NC}"
    exit 1
fi

echo -e "${YELLOW}⏹️  Stopping services...${NC}"
$COMPOSE_CMD -f docker-compose.yml down

echo -e "${YELLOW}🗑️  Removing containers and images...${NC}"
$COMPOSE_CMD -f docker-compose.yml down --rmi all --volumes --remove-orphans

# Stop Podman socket if we started it
pkill -f "podman system service" 2>/dev/null || true

echo -e "${GREEN}✅ Podman environment stopped successfully${NC}"
echo ""
echo -e "${BLUE}💡 To start the environment again, run:${NC}"
echo -e "${YELLOW}   ./scripts/start-podman.sh${NC}"
