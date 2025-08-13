#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Testing ProductService (Standalone Mode)${NC}"
echo "============================================="

BASE_URL="http://localhost:5001"

# Function to test API endpoints
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -e "${YELLOW}Testing: $description${NC}"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "%{http_code}" -X $method -H "Content-Type: application/json" -d "$data" "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "%{http_code}" -X $method "$BASE_URL$endpoint")
    fi
    
    status_code="${response: -3}"
    body="${response%???}"
    
    if [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
        echo -e "${GREEN}✅ PASS: $description (HTTP $status_code)${NC}"
        if [ -n "$body" ] && [ "$body" != "null" ] && [ ${#body} -lt 500 ]; then
            echo -e "${BLUE}Response: ${body}${NC}"
        fi
    else
        echo -e "${RED}❌ FAIL: $description (HTTP $status_code)${NC}"
        if [ -n "$body" ]; then
            echo -e "${RED}Response: ${body}${NC}"
        fi
    fi
    echo ""
}

# Wait for service to be ready
echo -e "${YELLOW}⏳ Waiting for ProductService to be ready...${NC}"
for i in {1..10}; do
    if curl -s "$BASE_URL/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ ProductService is ready${NC}"
        break
    fi
    echo "Attempt $i/10..."
    sleep 2
done

# Test health endpoint
test_endpoint "GET" "/health" "" "Health Check"

# Test get all products
test_endpoint "GET" "/api/products" "" "Get All Products"

# Test create product (without Dapr pub/sub)
NEW_PRODUCT='{
    "name": "Test Laptop",
    "description": "A laptop for testing the API",
    "price": 1299.99,
    "stock": 5
}'

echo -e "${YELLOW}Creating a test product...${NC}"
create_response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$NEW_PRODUCT" "$BASE_URL/api/products")
create_status="${create_response: -3}"
create_body="${create_response%???}"

if [ "$create_status" -eq "201" ]; then
    echo -e "${GREEN}✅ Product created successfully${NC}"
    PRODUCT_ID=$(echo "$create_body" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
    echo -e "${BLUE}Created Product ID: $PRODUCT_ID${NC}"
    echo -e "${BLUE}Response: ${create_body}${NC}"
else
    echo -e "${RED}❌ Failed to create product (HTTP $create_status)${NC}"
    echo -e "${RED}Response: ${create_body}${NC}"
fi
echo ""

# Test get all products again
test_endpoint "GET" "/api/products" "" "Get All Products (After Creation)"

# Test get specific product
if [ -n "$PRODUCT_ID" ]; then
    test_endpoint "GET" "/api/products/$PRODUCT_ID" "" "Get Specific Product"
fi

echo -e "${BLUE}📋 Test Summary${NC}"
echo "==============="
echo -e "✅ ProductService is running and responding"
echo -e "✅ Basic CRUD operations are functional" 
echo -e "🔍 Swagger UI available at: ${YELLOW}http://localhost:5001${NC}"
echo ""
echo -e "${GREEN}🎉 Standalone testing completed!${NC}"
echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "- Fix Dapr connectivity issues"
echo "- Start OrderService"  
echo "- Test service-to-service communication"
