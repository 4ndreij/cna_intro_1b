#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 Dapr Microservices Logs${NC}"
echo "=========================="

# Function to show logs for a specific service
show_logs() {
    local service_name=$1
    local log_file="$HOME/.dapr/logs/dapr_${service_name}.log"
    
    echo -e "${YELLOW}=== $service_name logs ===${NC}"
    
    if [ -f "$log_file" ]; then
        tail -n 50 "$log_file"
    else
        echo -e "${RED}Log file not found: $log_file${NC}"
    fi
    echo ""
}

# Check command line argument
case "$1" in
    "product")
        show_logs "productservice"
        ;;
    "order") 
        show_logs "orderservice"
        ;;
    "all"|"")
        echo -e "${BLUE}📦 ProductService Logs${NC}"
        echo "======================="
        show_logs "productservice"
        
        echo -e "${BLUE}🛒 OrderService Logs${NC}"
        echo "===================="
        show_logs "orderservice"
        ;;
    "follow")
        echo -e "${YELLOW}Following logs in real-time (Ctrl+C to stop)...${NC}"
        echo ""
        
        # Follow both service logs
        tail -f "$HOME/.dapr/logs/dapr_productservice.log" "$HOME/.dapr/logs/dapr_orderservice.log" 2>/dev/null &
        TAIL_PID=$!
        
        # Handle Ctrl+C gracefully
        trap 'kill $TAIL_PID 2>/dev/null; exit 0' SIGINT
        wait $TAIL_PID
        ;;
    "clear")
        echo -e "${YELLOW}Clearing log files...${NC}"
        rm -f "$HOME/.dapr/logs/dapr_productservice.log" 2>/dev/null
        rm -f "$HOME/.dapr/logs/dapr_orderservice.log" 2>/dev/null
        echo -e "${GREEN}✅ Log files cleared${NC}"
        ;;
    *)
        echo -e "${BLUE}Usage: $0 [product|order|all|follow|clear]${NC}"
        echo ""
        echo "Options:"
        echo "  product  - Show ProductService logs only"
        echo "  order    - Show OrderService logs only"
        echo "  all      - Show all service logs (default)"
        echo "  follow   - Follow logs in real-time"
        echo "  clear    - Clear all log files"
        exit 1
        ;;
esac
