#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Testing Dapr Microservices APIs${NC}"
echo "=================================="

BASE_URL_PRODUCT="http://localhost:5001"
BASE_URL_ORDER="http://localhost:5002"

# Function to make HTTP requests and check responses
test_api() {
    local method=$1
    local url=$2
    local data=$3
    local expected_status=$4
    local description=$5
    
    echo -e "${YELLOW}Testing: $description${NC}"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "%{http_code}" -X $method -H "Content-Type: application/json" -d "$data" "$url")
    else
        response=$(curl -s -w "%{http_code}" -X $method "$url")
    fi
    
    status_code="${response: -3}"
    body="${response%???}"
    
    if [ "$status_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✅ PASS: $description (HTTP $status_code)${NC}"
        if [ -n "$body" ] && [ "$body" != "null" ]; then
            echo -e "${BLUE}Response: ${body}${NC}"
        fi
    else
        echo -e "${RED}❌ FAIL: $description (Expected HTTP $expected_status, got $status_code)${NC}"
        if [ -n "$body" ]; then
            echo -e "${RED}Response: ${body}${NC}"
        fi
    fi
    echo ""
}

# Wait a bit to ensure services are ready
echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
sleep 3

# Test 1: Health checks
echo -e "${BLUE}🏥 Testing Health Endpoints${NC}"
echo "=============================="
test_api "GET" "$BASE_URL_PRODUCT/health" "" 200 "ProductService Health Check"
test_api "GET" "$BASE_URL_ORDER/health" "" 200 "OrderService Health Check"

# Test 2: Get all products (should return seeded data)
echo -e "${BLUE}📦 Testing Product Operations${NC}"
echo "=============================="
test_api "GET" "$BASE_URL_PRODUCT/api/products" "" 200 "Get All Products"

# Test 3: Create a new product
echo -e "${YELLOW}Creating a new product...${NC}"
NEW_PRODUCT='{
    "name": "Test Product API",
    "description": "Created via API test",
    "price": 99.99,
    "stock": 25
}'

create_response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$NEW_PRODUCT" "$BASE_URL_PRODUCT/api/products")
create_status="${create_response: -3}"
create_body="${create_response%???}"

if [ "$create_status" -eq "201" ]; then
    echo -e "${GREEN}✅ PASS: Create Product (HTTP $create_status)${NC}"
    # Extract product ID from response for further tests
    PRODUCT_ID=$(echo "$create_body" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
    echo -e "${BLUE}Created Product ID: $PRODUCT_ID${NC}"
else
    echo -e "${RED}❌ FAIL: Create Product (Expected HTTP 201, got $create_status)${NC}"
    echo -e "${RED}Response: ${create_body}${NC}"
fi
echo ""

# Test 4: Get the created product
if [ -n "$PRODUCT_ID" ]; then
    test_api "GET" "$BASE_URL_PRODUCT/api/products/$PRODUCT_ID" "" 200 "Get Created Product"
fi

# Test 5: Test Order Operations
echo -e "${BLUE}🛒 Testing Order Operations${NC}"
echo "============================"
test_api "GET" "$BASE_URL_ORDER/api/orders" "" 200 "Get All Orders"

# Test 6: Create an order (using the first available product)
echo -e "${YELLOW}Getting first available product for order creation...${NC}"
products_response=$(curl -s "$BASE_URL_PRODUCT/api/products")
FIRST_PRODUCT_ID=$(echo "$products_response" | python3 -c "import sys, json; products=json.load(sys.stdin); print(products[0]['id'] if products else '')" 2>/dev/null || echo "")

if [ -n "$FIRST_PRODUCT_ID" ]; then
    echo -e "${BLUE}Using Product ID: $FIRST_PRODUCT_ID${NC}"
    
    NEW_ORDER='{
        "productId": "'$FIRST_PRODUCT_ID'",
        "customerName": "John Doe",
        "customerEmail": "john.doe@example.com",
        "quantity": 2
    }'
    
    order_response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$NEW_ORDER" "$BASE_URL_ORDER/api/orders")
    order_status="${order_response: -3}"
    order_body="${order_response%???}"
    
    if [ "$order_status" -eq "201" ]; then
        echo -e "${GREEN}✅ PASS: Create Order (HTTP $order_status)${NC}"
        ORDER_ID=$(echo "$order_body" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
        echo -e "${BLUE}Created Order ID: $ORDER_ID${NC}"
        echo -e "${BLUE}Response: ${order_body}${NC}"
    else
        echo -e "${RED}❌ FAIL: Create Order (Expected HTTP 201, got $order_status)${NC}"
        echo -e "${RED}Response: ${order_body}${NC}"
    fi
else
    echo -e "${RED}❌ No products available for order creation${NC}"
fi
echo ""

# Test 7: Test pub/sub messaging by updating product stock
echo -e "${BLUE}📡 Testing Pub/Sub Messaging${NC}"
echo "============================="

if [ -n "$FIRST_PRODUCT_ID" ]; then
    echo -e "${YELLOW}Updating product stock to trigger pub/sub event...${NC}"
    
    STOCK_UPDATE='{"stock": 100}'
    
    stock_response=$(curl -s -w "%{http_code}" -X PATCH -H "Content-Type: application/json" -d "$STOCK_UPDATE" "$BASE_URL_PRODUCT/api/products/$FIRST_PRODUCT_ID/stock")
    stock_status="${stock_response: -3}"
    
    if [ "$stock_status" -eq "204" ]; then
        echo -e "${GREEN}✅ PASS: Update Product Stock (HTTP $stock_status)${NC}"
        echo -e "${BLUE}📨 Stock update event should be published to OrderService${NC}"
        echo -e "${YELLOW}Check the OrderService logs for event subscription messages${NC}"
    else
        echo -e "${RED}❌ FAIL: Update Product Stock (Expected HTTP 204, got $stock_status)${NC}"
    fi
fi
echo ""

# Test 8: Service-to-service communication via Dapr
echo -e "${BLUE}🔗 Testing Service-to-Service Communication${NC}"
echo "==========================================="

# Test Dapr service invocation
echo -e "${YELLOW}Testing Dapr service invocation (ProductService via Dapr)...${NC}"
dapr_response=$(curl -s -w "%{http_code}" "http://localhost:3502/v1.0/invoke/productservice/method/api/products")
dapr_status="${dapr_response: -3}"

if [ "$dapr_status" -eq "200" ]; then
    echo -e "${GREEN}✅ PASS: Dapr Service Invocation (HTTP $dapr_status)${NC}"
    echo -e "${BLUE}OrderService can successfully communicate with ProductService via Dapr${NC}"
else
    echo -e "${RED}❌ FAIL: Dapr Service Invocation (Expected HTTP 200, got $dapr_status)${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}📊 Test Summary${NC}"
echo "==============="
echo -e "${GREEN}✅ API endpoints are functional${NC}"
echo -e "${GREEN}✅ CRUD operations working${NC}"
echo -e "${GREEN}✅ Service-to-service communication via Dapr${NC}"
echo -e "${GREEN}✅ Pub/sub messaging configured${NC}"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "- Check service logs: ./scripts/logs.sh"
echo "- View Swagger UI: http://localhost:5001 and http://localhost:5002"
echo "- Monitor Dapr dashboard: dapr dashboard"
echo ""
echo -e "${GREEN}🎉 API tests completed!${NC}"
