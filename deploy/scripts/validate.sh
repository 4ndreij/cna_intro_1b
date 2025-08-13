#!/bin/bash

# Post-Deployment Validation Script
# Validates that the deployed services are working correctly

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
PREFIX=""
TIMEOUT=300  # 5 minutes

show_help() {
    cat << EOF
Azure Container Apps Validation Script

USAGE:
    $0 --resource-group <name> --prefix <prefix> [OPTIONS]

REQUIRED:
    -g, --resource-group NAME    Azure Resource Group name
    -p, --prefix PREFIX          Resource name prefix used during deployment

OPTIONS:
    -t, --timeout SECONDS       Timeout for health checks [default: 300]
    -h, --help                  Show this help message

EXAMPLES:
    # Validate deployment
    $0 -g myapp-dev-rg -p daprmicro

    # Validate with custom timeout
    $0 -g myapp-dev-rg -p daprmicro --timeout 600

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
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

if [[ -z "$PREFIX" ]]; then
    echo -e "${RED}❌ Prefix is required${NC}"
    show_help
    exit 1
fi

# Resource names
PRODUCTSERVICE_NAME="${PREFIX}-productservice"
ORDERSERVICE_NAME="${PREFIX}-orderservice"
REDIS_NAME="${PREFIX}-redis"
ENVIRONMENT_NAME="${PREFIX}-env"

echo -e "${CYAN}🧪 Azure Container Apps Validation${NC}"
echo -e "${CYAN}=================================${NC}"
echo -e "   Resource Group: $RESOURCE_GROUP"
echo -e "   Prefix: $PREFIX"
echo -e "   Timeout: ${TIMEOUT}s"
echo ""

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

run_check() {
    local check_name="$1"
    local check_command="$2"
    
    echo -n -e "${YELLOW}🔍 $check_name...${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if eval "$check_command" &> /dev/null; then
        echo -e " ${GREEN}✅ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e " ${RED}❌ FAIL${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

run_check_with_output() {
    local check_name="$1"
    local check_command="$2"
    
    echo -e "${YELLOW}🔍 $check_name${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local output
    if output=$(eval "$check_command" 2>&1); then
        echo -e "${GREEN}✅ PASS${NC}"
        echo "$output" | sed 's/^/   /'
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        echo "$output" | sed 's/^/   /' | head -5
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Check Prerequisites
echo -e "${BLUE}📋 Prerequisites${NC}"
run_check "Azure CLI available" "command -v az"
run_check "Logged into Azure" "az account show"
run_check "Resource group exists" "az group show --name '$RESOURCE_GROUP'"

# Check Azure Resources
echo ""
echo -e "${BLUE}🏗️ Infrastructure Resources${NC}"
run_check "Container Apps Environment" "az containerapp env show --name '$ENVIRONMENT_NAME' --resource-group '$RESOURCE_GROUP'"
run_check "Container Registry" "az acr show --name '${PREFIX}registry' --resource-group '$RESOURCE_GROUP'"

# Check Container Apps
echo ""
echo -e "${BLUE}📦 Container Applications${NC}"
run_check "Redis Container App" "az containerapp show --name '$REDIS_NAME' --resource-group '$RESOURCE_GROUP'"
run_check "ProductService Container App" "az containerapp show --name '$PRODUCTSERVICE_NAME' --resource-group '$RESOURCE_GROUP'"
run_check "OrderService Container App" "az containerapp show --name '$ORDERSERVICE_NAME' --resource-group '$RESOURCE_GROUP'"

# Check Container App Status
echo ""
echo -e "${BLUE}⚡ Application Status${NC}"

check_app_ready() {
    local app_name="$1"
    local status=$(az containerapp show --name "$app_name" --resource-group "$RESOURCE_GROUP" --query "properties.runningStatus" --output tsv 2>/dev/null || echo "Unknown")
    [[ "$status" == "Running" ]]
}

run_check "Redis status" "check_app_ready '$REDIS_NAME'"
run_check "ProductService status" "check_app_ready '$PRODUCTSERVICE_NAME'"
run_check "OrderService status" "check_app_ready '$ORDERSERVICE_NAME'"

# Get service URLs
echo ""
echo -e "${BLUE}🌐 Service URLs${NC}"

PRODUCT_SERVICE_URL=""
ORDER_SERVICE_URL=""

if az containerapp show --name "$PRODUCTSERVICE_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    PRODUCT_SERVICE_URL=$(az containerapp show \
        --name "$PRODUCTSERVICE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.configuration.ingress.fqdn" \
        --output tsv)
    echo -e "   ProductService: ${GREEN}https://$PRODUCT_SERVICE_URL${NC}"
fi

if az containerapp show --name "$ORDERSERVICE_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    ORDER_SERVICE_URL=$(az containerapp show \
        --name "$ORDERSERVICE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.configuration.ingress.fqdn" \
        --output tsv)
    echo -e "   OrderService: ${GREEN}https://$ORDER_SERVICE_URL${NC}"
fi

# Health Checks
if [[ -n "$PRODUCT_SERVICE_URL" ]] || [[ -n "$ORDER_SERVICE_URL" ]]; then
    echo ""
    echo -e "${BLUE}🏥 Health Checks${NC}"
    
    # Wait for services to be ready
    wait_for_service() {
        local service_name="$1"
        local url="$2"
        local endpoint="$3"
        local timeout="$4"
        
        echo -e "${YELLOW}⏳ Waiting for $service_name to be ready...${NC}"
        local start_time=$(date +%s)
        
        while true; do
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            
            if [[ $elapsed -gt $timeout ]]; then
                echo -e "${RED}❌ Timeout waiting for $service_name${NC}"
                return 1
            fi
            
            if curl -s -f "https://$url$endpoint" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ $service_name is ready (${elapsed}s)${NC}"
                return 0
            fi
            
            echo -n "."
            sleep 5
        done
    }
    
    # Test health endpoints
    if [[ -n "$PRODUCT_SERVICE_URL" ]]; then
        if wait_for_service "ProductService" "$PRODUCT_SERVICE_URL" "/health" $TIMEOUT; then
            run_check_with_output "ProductService health" "curl -s https://$PRODUCT_SERVICE_URL/health"
            run_check_with_output "ProductService products endpoint" "curl -s https://$PRODUCT_SERVICE_URL/api/products | head -5"
        fi
    fi
    
    if [[ -n "$ORDER_SERVICE_URL" ]]; then
        if wait_for_service "OrderService" "$ORDER_SERVICE_URL" "/health" $TIMEOUT; then
            run_check_with_output "OrderService health" "curl -s https://$ORDER_SERVICE_URL/health"
            run_check_with_output "OrderService orders endpoint" "curl -s https://$ORDER_SERVICE_URL/api/orders"
        fi
    fi
fi

# Dapr Components Check
echo ""
echo -e "${BLUE}⚙️ Dapr Components${NC}"
run_check_with_output "Dapr state store component" "az containerapp env dapr-component show --name '$ENVIRONMENT_NAME' --resource-group '$RESOURCE_GROUP' --dapr-component-name statestore"
run_check_with_output "Dapr pub/sub component" "az containerapp env dapr-component show --name '$ENVIRONMENT_NAME' --resource-group '$RESOURCE_GROUP' --dapr-component-name product-pubsub"

# Container logs check (recent errors)
echo ""
echo -e "${BLUE}📋 Recent Application Logs${NC}"

check_recent_logs() {
    local app_name="$1"
    echo -e "${YELLOW}📋 Recent logs for $app_name:${NC}"
    az containerapp logs show \
        --name "$app_name" \
        --resource-group "$RESOURCE_GROUP" \
        --tail 10 \
        --output table 2>/dev/null | head -15 || echo "   No recent logs available"
}

if az containerapp show --name "$PRODUCTSERVICE_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    check_recent_logs "$PRODUCTSERVICE_NAME"
fi

echo ""
if az containerapp show --name "$ORDERSERVICE_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    check_recent_logs "$ORDERSERVICE_NAME"
fi

# Final Summary
echo ""
echo -e "${CYAN}📊 Validation Summary${NC}"
echo -e "${CYAN}====================${NC}"
echo -e "   Total Checks: $TOTAL_CHECKS"
echo -e "   ${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "   ${RED}Failed: $FAILED_CHECKS${NC}"

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}🎉 All validations passed! Your deployment is healthy.${NC}"
    
    if [[ -n "$PRODUCT_SERVICE_URL" ]] && [[ -n "$ORDER_SERVICE_URL" ]]; then
        echo ""
        echo -e "${BLUE}🧪 Manual Testing Commands:${NC}"
        echo -e "   # Test ProductService"
        echo -e "   curl https://$PRODUCT_SERVICE_URL/api/products"
        echo -e ""
        echo -e "   # Test OrderService"
        echo -e "   curl https://$ORDER_SERVICE_URL/api/orders"
        echo -e ""
        echo -e "   # Create a test order"
        echo -e '   curl -X POST https://'"$ORDER_SERVICE_URL"'/api/orders \\'
        echo -e '     -H "Content-Type: application/json" \\'
        echo -e '     -d '"'"'{"productId":1,"quantity":1}'"'"
    fi
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some validations failed. Please check the deployment.${NC}"
    echo -e "${YELLOW}💡 Use the cleanup.sh script to remove resources if needed.${NC}"
    exit 1
fi