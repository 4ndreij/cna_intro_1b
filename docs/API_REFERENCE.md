# API Reference

Complete API documentation for the microservices solution.

## 🌐 Service Endpoints

### Local Development
- **ProductService**: `http://localhost:5001`
- **OrderService**: `http://localhost:5002`
- **Swagger UI**: 
  - ProductService: `http://localhost:5001/swagger`
  - OrderService: `http://localhost:5002/swagger`

### Azure Container Apps
- **ProductService**: `https://<app-name>-productservice.azurecontainerapps.io`
- **OrderService**: `https://<app-name>-orderservice.azurecontainerapps.io`

## 🛍️ ProductService API

### Products

#### GET /api/products
Get all products with optional filtering.

```http
GET /api/products?name=<search>&minPrice=<number>&maxPrice=<number>
Accept: application/json
```

**Response:**
```json
[
  {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "name": "Product Name",
    "description": "Product description",
    "price": 99.99,
    "stock": 100,
    "createdAt": "2024-01-01T12:00:00Z",
    "updatedAt": "2024-01-01T12:00:00Z"
  }
]
```

#### GET /api/products/{id}
Get a specific product by ID.

```http
GET /api/products/3fa85f64-5717-4562-b3fc-2c963f66afa6
Accept: application/json
```

**Response:**
```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "name": "Product Name",
  "description": "Product description",
  "price": 99.99,
  "stock": 100,
  "createdAt": "2024-01-01T12:00:00Z",
  "updatedAt": "2024-01-01T12:00:00Z"
}
```

#### POST /api/products
Create a new product.

```http
POST /api/products
Content-Type: application/json

{
  "name": "New Product",
  "description": "Product description",
  "price": 99.99,
  "stock": 100
}
```

**Response:**
```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "name": "New Product",
  "description": "Product description", 
  "price": 99.99,
  "stock": 100,
  "createdAt": "2024-01-01T12:00:00Z",
  "updatedAt": "2024-01-01T12:00:00Z"
}
```

#### PUT /api/products/{id}
Update an existing product.

```http
PUT /api/products/3fa85f64-5717-4562-b3fc-2c963f66afa6
Content-Type: application/json

{
  "name": "Updated Product",
  "description": "Updated description",
  "price": 149.99,
  "stock": 50
}
```

#### DELETE /api/products/{id}
Delete a product.

```http
DELETE /api/products/3fa85f64-5717-4562-b3fc-2c963f66afa6
```

### Product Inventory

#### PATCH /api/products/{id}/stock
Update product stock (used internally by OrderService).

```http
PATCH /api/products/3fa85f64-5717-4562-b3fc-2c963f66afa6/stock
Content-Type: application/json

{
  "quantity": -5,
  "operation": "decrease"
}
```

## 📦 OrderService API

### Orders

#### GET /api/orders
Get all orders with optional filtering.

```http
GET /api/orders?customerEmail=<email>&status=<status>
Accept: application/json
```

**Response:**
```json
[
  {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "productId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "productName": "Product Name",
    "customerName": "John Doe",
    "customerEmail": "john@example.com",
    "quantity": 2,
    "unitPrice": 99.99,
    "totalPrice": 199.98,
    "status": "Completed",
    "createdAt": "2024-01-01T12:00:00Z",
    "updatedAt": "2024-01-01T12:00:00Z"
  }
]
```

#### GET /api/orders/{id}
Get a specific order by ID.

```http
GET /api/orders/3fa85f64-5717-4562-b3fc-2c963f66afa6
Accept: application/json
```

#### POST /api/orders
Create a new order.

```http
POST /api/orders
Content-Type: application/json

{
  "productId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "customerName": "John Doe",
  "customerEmail": "john@example.com",
  "quantity": 2
}
```

**Process:**
1. Validates input data
2. Calls ProductService to get product details and check stock
3. Creates order with calculated total price
4. Updates product stock via ProductService
5. Publishes order created event

**Response:**
```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "productId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "productName": "Product Name",
  "customerName": "John Doe",
  "customerEmail": "john@example.com",
  "quantity": 2,
  "unitPrice": 99.99,
  "totalPrice": 199.98,
  "status": "Completed",
  "createdAt": "2024-01-01T12:00:00Z",
  "updatedAt": "2024-01-01T12:00:00Z"
}
```

#### DELETE /api/orders/{id}
Cancel an order (restores product stock).

```http
DELETE /api/orders/3fa85f64-5717-4562-b3fc-2c963f66afa6
```

## 🏥 Health Endpoints

### ProductService Health

#### GET /health
Basic health check.

```http
GET /health
```

**Response:**
```json
{
  "status": "Healthy",
  "totalDuration": "00:00:00.001",
  "entries": {
    "database": {
      "status": "Healthy",
      "duration": "00:00:00.001"
    },
    "dapr": {
      "status": "Healthy", 
      "duration": "00:00:00.001"
    }
  }
}
```

#### GET /health/ready
Readiness probe (Kubernetes-compatible).

#### GET /health/live
Liveness probe (Kubernetes-compatible).

### OrderService Health

Same endpoints as ProductService with additional checks for:
- ProductService connectivity
- Pub/sub system connectivity

## 📊 Dapr Integration

### Service Invocation

Services communicate through Dapr service invocation:

```http
# Direct Dapr call to ProductService
POST http://localhost:3500/v1.0/invoke/productservice/method/api/products/{id}/stock
Content-Type: application/json

{
  "quantity": -1,
  "operation": "decrease"
}
```

### State Management

```http
# Get state directly via Dapr
GET http://localhost:3500/v1.0/state/statestore/products||{id}

# Set state directly via Dapr  
POST http://localhost:3500/v1.0/state/statestore
Content-Type: application/json

[
  {
    "key": "products||{id}",
    "value": {
      "id": "{id}",
      "name": "Product Name",
      "price": 99.99
    }
  }
]
```

### Pub/Sub Events

**Order Created Event:**
```json
{
  "specversion": "1.0",
  "type": "order.created",
  "source": "orderservice",
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "time": "2024-01-01T12:00:00Z",
  "data": {
    "orderId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "productId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "customerId": "john@example.com",
    "quantity": 2,
    "totalPrice": 199.98
  }
}
```

## 🔐 Error Responses

### Standard Error Format

```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.1",
  "title": "Bad Request",
  "status": 400,
  "detail": "The request body is invalid",
  "instance": "/api/products",
  "errors": {
    "Name": ["The Name field is required"],
    "Price": ["Price must be greater than 0"]
  }
}
```

### HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 200 | OK | Successful GET, PUT requests |
| 201 | Created | Successful POST requests |
| 204 | No Content | Successful DELETE requests |
| 400 | Bad Request | Invalid input data |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Business rule violation (e.g., insufficient stock) |
| 500 | Internal Server Error | Unexpected server errors |
| 503 | Service Unavailable | Dependency service unavailable |

### Common Error Scenarios

**Product Not Found:**
```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.4",
  "title": "Not Found",
  "status": 404,
  "detail": "Product with ID '3fa85f64-5717-4562-b3fc-2c963f66afa6' was not found"
}
```

**Insufficient Stock:**
```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.8",
  "title": "Conflict", 
  "status": 409,
  "detail": "Insufficient stock. Available: 5, Requested: 10"
}
```

**Service Unavailable:**
```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.6.4",
  "title": "Service Unavailable",
  "status": 503,
  "detail": "ProductService is currently unavailable"
}
```

## 📝 Request/Response Examples

### Complete Order Flow

**1. Create Product:**
```bash
curl -X POST http://localhost:5001/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Gaming Laptop",
    "description": "High-performance gaming laptop",
    "price": 1299.99,
    "stock": 10
  }'
```

**2. Create Order:**
```bash
curl -X POST http://localhost:5002/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "productId": "<product-id-from-step-1>",
    "customerName": "John Doe",
    "customerEmail": "john@example.com", 
    "quantity": 2
  }'
```

**3. Verify Stock Update:**
```bash
curl http://localhost:5001/api/products/<product-id>
# Stock should now be 8
```

### Batch Operations

**Get Multiple Products:**
```bash
curl "http://localhost:5001/api/products?minPrice=100&maxPrice=2000"
```

**Filter Orders by Customer:**
```bash
curl "http://localhost:5002/api/orders?customerEmail=john@example.com"
```

## 🧪 Testing with curl

### Product CRUD Operations
```bash
# Create
PRODUCT_ID=$(curl -s -X POST http://localhost:5001/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","description":"Test","price":99.99,"stock":10}' \
  | jq -r '.id')

# Read
curl http://localhost:5001/api/products/$PRODUCT_ID | jq

# Update  
curl -X PUT http://localhost:5001/api/products/$PRODUCT_ID \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Product","description":"Updated","price":149.99,"stock":5}' | jq

# Delete
curl -X DELETE http://localhost:5001/api/products/$PRODUCT_ID
```

### Order Operations
```bash
# Create order (requires existing product)
ORDER_ID=$(curl -s -X POST http://localhost:5002/api/orders \
  -H "Content-Type: application/json" \
  -d '{"productId":"'$PRODUCT_ID'","customerName":"Test User","customerEmail":"test@example.com","quantity":1}' \
  | jq -r '.id')

# Get order
curl http://localhost:5002/api/orders/$ORDER_ID | jq

# Cancel order
curl -X DELETE http://localhost:5002/api/orders/$ORDER_ID
```

## 📚 Additional Resources

- [OpenAPI Specifications](../src/ProductService/wwwroot/swagger.json)
- [Postman Collection](./postman-collection.json) *(if available)*
- [Development Guide](./DEVELOPMENT.md)
- [Architecture Documentation](./ARCHITECTURE.md)