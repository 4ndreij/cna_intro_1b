# Local Development Setup Guide

This guide will help you set up and run the Dapr microservices locally using either native Dapr CLI or Podman containers.

## Prerequisites

### Required Software
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Dapr CLI](https://docs.dapr.io/getting-started/install-dapr-cli/)
- [Redis](https://redis.io/download) (or Docker/Podman to run Redis container)

### Optional Software
- [Podman](https://podman.io/getting-started/installation) or Docker (for containerized development)
- [curl](https://curl.se/) (for API testing)

## Setup Options

### Option 1: Native Development with Dapr CLI (Recommended for development)

This approach runs the .NET services directly on your machine with Dapr sidecars.

#### 1. Initialize Dapr
```bash
dapr uninstall --all  # Clean any existing installation
dapr init
```

#### 2. Start Redis (if not installed locally)
```bash
# Using Docker/Podman
docker run -d -p 6379:6379 --name dapr-redis redis:alpine
# OR
podman run -d -p 6379:6379 --name dapr-redis redis:alpine
```

#### 3. Start the Development Environment
```bash
./scripts/start-dev.sh
```

This script will:
- ✅ Check prerequisites
- 🔨 Build the solution
- 🚀 Start ProductService on port 5001 with Dapr sidecar
- 🚀 Start OrderService on port 5002 with Dapr sidecar
- 🔍 Perform health checks

#### 4. Test the APIs
```bash
./scripts/test-apis.sh
```

#### 5. Stop the Environment
```bash
./scripts/stop-dev.sh
```

### Option 2: Containerized Development with Podman

This approach runs everything in containers for a production-like experience.

#### 1. Start with Podman
```bash
./scripts/start-podman.sh
```

#### 2. Test the APIs
```bash
./scripts/test-apis.sh
```

#### 3. Stop the Environment
```bash
./scripts/stop-podman.sh
```

## Service Endpoints

### Development URLs
| Service | API | Swagger UI | Dapr Sidecar |
|---------|-----|------------|--------------|
| ProductService | http://localhost:5001/api/products | http://localhost:5001 | http://localhost:3501 |
| OrderService | http://localhost:5002/api/orders | http://localhost:5002 | http://localhost:3502 |

### Health Checks
- ProductService: http://localhost:5001/health
- OrderService: http://localhost:5002/health

## Development Workflow

### 1. Making Code Changes
- Edit code in VS Code or your preferred IDE
- The `start-dev.sh` script runs with file watching, so changes are automatically recompiled
- For container development, rebuild with: `./scripts/start-podman.sh`

### 2. Viewing Logs
```bash
# View all service logs
./scripts/logs.sh

# View specific service logs
./scripts/logs.sh product    # ProductService only
./scripts/logs.sh order      # OrderService only

# Follow logs in real-time
./scripts/logs.sh follow

# Clear logs
./scripts/logs.sh clear
```

### 3. Testing Pub/Sub Communication

The services communicate via Dapr pub/sub:

**Product Events** (Published by ProductService):
- `product-created` - When a product is created
- `product-updated` - When a product is updated
- `product-deleted` - When a product is deleted
- `product-stock-changed` - When stock is updated

**Order Events** (Published by OrderService):
- `order-created` - When an order is created
- `order-status-changed` - When order status changes
- `order-cancelled` - When an order is cancelled

**Testing Flow:**
1. Create a product → ProductService publishes `product-created` → OrderService receives it
2. Update product stock → ProductService publishes `product-stock-changed` → OrderService receives it
3. Create an order → OrderService calls ProductService → Stock is automatically updated

### 4. Service-to-Service Communication

OrderService communicates with ProductService via Dapr service invocation:
```csharp
// Get product details when creating an order
var product = await _daprClient.InvokeMethodAsync<ProductDto>(
    "productservice", 
    $"api/products/{productId}");

// Update product stock
await _daprClient.InvokeMethodAsync(
    "productservice",
    $"api/products/{productId}/stock",
    new { stock = newStock });
```

## Troubleshooting

### Common Issues

**1. Port Already in Use**
```bash
# Kill processes using ports 5001, 5002, 3501, 3502
lsof -ti:5001,5002,3501,3502 | xargs kill -9
```

**2. Redis Connection Issues**
```bash
# Check if Redis is running
redis-cli ping

# Start Redis container
docker run -d -p 6379:6379 --name dapr-redis redis:alpine
```

**3. Dapr Not Initialized**
```bash
dapr init
```

**4. Build Errors**
```bash
# Clean and rebuild
dotnet clean
dotnet restore
dotnet build
```

### Debugging Tips

1. **Check Dapr Components**: Ensure components in `infrastructure/dapr/` are correctly configured
2. **Verify Service Registration**: Use `dapr list` to see running applications
3. **Monitor Dapr Dashboard**: Run `dapr dashboard` to open the Dapr management UI
4. **Check Component Status**: Use the Dapr dashboard to verify pub/sub and state store connections

## Next Steps

- ✅ **Phase 1**: Project structure and .NET 8 services
- ✅ **Phase 2**: Dapr configuration for local development  
- ⏳ **Phase 3**: Basic Web APIs with pub/sub messaging
- ⏳ **Phase 4**: Containerization with Podman
- ⏳ **Phase 5**: Azure infrastructure templates

Continue with Phase 3 to implement more advanced messaging patterns and observability features!
