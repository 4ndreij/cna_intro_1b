# Development Guide

Complete guide for local development of the cloud-native microservices solution.

## 🛠️ Prerequisites

### Required Tools
```bash
# Core development tools
.NET 8 SDK (8.0.100 or later)
Dapr CLI (1.15.0 or later)
Podman (5.0 or later)

# Optional tools for enhanced development
Azure CLI (2.60+) - for cloud deployment
Redis CLI - for Redis interaction
jq - for JSON processing in examples

# Verify installations
dotnet --version
dapr --version  
podman --version
az --version
```

### Initial Setup
```bash
# Clone repository
git clone <repository-url>
cd cna_intro_1b

# Install Dapr runtime
dapr init

# Restore dependencies
dotnet restore
```

## 🚀 Development Workflows

### Option 1: Native Development (Recommended for Development)

**Fastest for development with hot reload and debugging support.**

```bash
# Start all services with Dapr sidecars
./scripts/start-dev.sh

# Services will be available at:
# ProductService: http://localhost:5001
# OrderService: http://localhost:5002  
# Dapr Dashboard: http://localhost:8080
```

**What this does:**
- Starts Redis container for state/pub-sub
- Runs ProductService with Dapr sidecar on port 3500
- Runs OrderService with Dapr sidecar on port 3501
- Enables hot reload for code changes
- Provides debugging capabilities in IDE

### Option 2: Container Development (Production-like)

**Best for testing production scenarios and final validation.**

```bash
# Build container images
./scripts/build-images.sh

# Start containerized services with Dapr
./scripts/run-containers.sh

# Services will be available at:
# ProductService: http://localhost:5001
# OrderService: http://localhost:5002
# Redis Insight: http://localhost:8001 (if enabled)
```

**What this does:**
- Builds optimized production containers
- Creates isolated container network
- Runs services with security constraints
- Simulates Azure Container Apps environment

## 🔧 Development Commands

### Building & Running

```bash
# Build solution
dotnet build

# Run specific service
dotnet run --project src/ProductService/
dotnet run --project src/OrderService/

# Build containers manually
podman build -t productservice:latest -f src/ProductService/Dockerfile .
podman build -t orderservice:latest -f src/OrderService/Dockerfile .

# View running containers
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Testing & Debugging

```bash
# Run all tests
dotnet test

# Run tests with coverage
dotnet test --collect:"XPlat Code Coverage"

# Run specific test project
dotnet test src/Tests/ProductService.Tests/

# Watch mode (re-run tests on file change)
dotnet watch test src/Tests/ProductService.Tests/

# Debug tests in IDE
# Set breakpoints and use IDE debugging features
```

### Monitoring & Logs

```bash
# View service logs (native)
# Logs appear in terminal where you ran start-dev.sh

# View container logs
podman logs -f productservice
podman logs -f orderservice
podman logs -f redis

# View Dapr logs
dapr logs --app-id productservice
dapr logs --app-id orderservice

# Access Dapr dashboard
# Open http://localhost:8080 in browser
```

## 🧪 API Testing

### Health Checks

```bash
# Service health
curl http://localhost:5001/health | jq
curl http://localhost:5002/health | jq

# Dapr health
curl http://localhost:3500/v1.0/healthz
curl http://localhost:3501/v1.0/healthz
```

### Product Service API

```bash
# Get all products
curl http://localhost:5001/api/products | jq

# Get specific product
curl http://localhost:5001/api/products/{id} | jq

# Create product
curl -X POST http://localhost:5001/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "description": "A test product for development",
    "price": 99.99,
    "stock": 100
  }' | jq

# Update product
curl -X PUT http://localhost:5001/api/products/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Product",
    "description": "Updated description",
    "price": 149.99,
    "stock": 50
  }' | jq

# Delete product
curl -X DELETE http://localhost:5001/api/products/{id}
```

### Order Service API

```bash
# Get all orders
curl http://localhost:5002/api/orders | jq

# Get specific order
curl http://localhost:5002/api/orders/{id} | jq

# Create order (tests service-to-service communication)
curl -X POST http://localhost:5002/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "productId": "<product-id-from-above>",
    "customerName": "John Doe",
    "customerEmail": "john@example.com",
    "quantity": 2
  }' | jq

# Cancel order
curl -X DELETE http://localhost:5002/api/orders/{id}
```

## 🔍 Debugging Guide

### IDE Setup

**Visual Studio Code:**
```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "ProductService",
      "type": "coreclr",
      "request": "launch",
      "program": "${workspaceFolder}/src/ProductService/bin/Debug/net8.0/ProductService.dll",
      "cwd": "${workspaceFolder}/src/ProductService",
      "env": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  ]
}
```

**Visual Studio:**
- Set multiple startup projects (ProductService, OrderService)
- Configure environment variables in project properties
- Use built-in debugging features

### Common Debugging Scenarios

**Service Communication Issues:**
```bash
# Check Dapr service discovery
curl http://localhost:3500/v1.0/metadata | jq

# Test direct service invocation
curl -X POST http://localhost:3500/v1.0/invoke/orderservice/method/api/orders \
  -H "Content-Type: application/json" \
  -d '{"productId":"test","customerName":"Debug","quantity":1}'
```

**State Management Issues:**
```bash
# Check Redis state
redis-cli -h localhost -p 6379
# > KEYS *
# > GET productservice||products||{id}
```

**Pub/Sub Issues:**
```bash
# Monitor Redis pub/sub
redis-cli -h localhost -p 6379
# > MONITOR
# Watch for published messages
```

## 🏗️ Code Organization

### Project Structure
```
src/
├── ProductService/
│   ├── Controllers/          # API endpoints
│   ├── Services/            # Business logic
│   ├── Data/                # Entity Framework contexts
│   ├── Validators/          # FluentValidation rules
│   ├── Models/              # Domain models
│   └── Program.cs           # Application entry point
├── OrderService/
│   ├── Controllers/         # API endpoints
│   ├── Services/           # Business logic with Dapr
│   ├── Data/               # Entity Framework contexts
│   ├── Validators/         # FluentValidation rules
│   ├── Models/             # Domain models
│   └── Program.cs          # Application entry point
├── Shared/
│   ├── Models/             # Shared domain entities
│   ├── DTOs/               # Data transfer objects
│   ├── Events/             # Event contracts
│   └── Extensions/         # Common extensions
└── Tests/
    ├── ProductService.Tests/
    ├── OrderService.Tests/
    └── Shared.Tests/
```

### Development Best Practices

**Code Quality:**
- Follow Clean Architecture principles
- Use dependency injection for testability
- Implement proper error handling
- Write comprehensive unit tests

**API Design:**
- RESTful endpoints with proper HTTP verbs
- Consistent response formats
- Comprehensive OpenAPI documentation
- Input validation with FluentValidation

**Dapr Integration:**
- Use Dapr SDK for service invocation
- Implement pub/sub for loose coupling
- Leverage state management for persistence
- Add proper error handling for Dapr calls

## 🔄 Development Workflow

### Typical Development Session

1. **Start Development Environment**
   ```bash
   ./scripts/start-dev.sh
   ```

2. **Make Code Changes**
   - Edit code in your preferred IDE
   - Hot reload automatically updates running services

3. **Test Changes**
   ```bash
   # Quick API test
   curl http://localhost:5001/api/products | jq
   
   # Run relevant unit tests
   dotnet test src/Tests/ProductService.Tests/
   ```

4. **Debug if Needed**
   - Set breakpoints in IDE
   - Use debugging features
   - Check logs for issues

5. **Validate with Containers**
   ```bash
   # Stop native development
   ./scripts/stop-dev.sh
   
   # Build and test containers
   ./scripts/build-images.sh
   ./scripts/run-containers.sh
   ```

### Environment Management

**Development Settings:**
- Uses in-memory database for fast iteration
- Enables detailed logging and debugging
- Hot reload for immediate feedback
- Simplified security for development

**Production-like Testing:**
- Uses containerized services
- Simulates resource constraints
- Tests deployment configurations
- Validates security settings

## 🚨 Troubleshooting

### Common Issues

**Dapr not starting:**
```bash
# Reinitialize Dapr
dapr uninstall
dapr init

# Check Dapr status
dapr status
```

**Port conflicts:**
```bash
# Check what's using ports
netstat -tulpn | grep :5001
netstat -tulpn | grep :5002

# Kill processes if needed
kill -9 <pid>
```

**Container issues:**
```bash
# Clean up containers
podman stop $(podman ps -q)
podman rm $(podman ps -aq)

# Clean up images
podman rmi $(podman images -q)

# Rebuild from scratch
./scripts/build-images.sh --no-cache
```

**Database issues:**
```bash
# Clear in-memory database (restart service)
# Or for persistent databases:
dotnet ef database drop --project src/ProductService/
dotnet ef database update --project src/ProductService/
```

For more detailed troubleshooting, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

## 📚 Additional Resources

- [Architecture Documentation](./ARCHITECTURE.md)
- [Deployment Guide](./DEPLOYMENT.md) 
- [API Reference](./API_REFERENCE.md)
- [Dapr Documentation](https://docs.dapr.io/)
- [.NET 8 Documentation](https://docs.microsoft.com/en-us/dotnet/)