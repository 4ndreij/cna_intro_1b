# Cloud-Native Microservices with Dapr

A production-ready microservices application built with .NET 8, demonstrating cloud-native patterns with Dapr service mesh, containerization, and Azure Container Apps deployment.

## 🚀 Quick Start

### Prerequisites
```bash
# Required tools
.NET 8 SDK (8.0.100+)
Dapr CLI (1.15.0+)  
Podman (5.0+)
Azure CLI (2.60+) # For cloud deployment
```

### 5-Minute Setup
```bash
# 1. Clone and setup
git clone <repository-url>
cd cna_intro_1b

# 2. Initialize Dapr
dapr init

# 3. Start services (choose one)
./scripts/start-dev.sh        # Native development (fastest)
./scripts/run-containers.sh   # Container development (production-like)

# 4. Test the APIs
curl http://localhost:5001/api/products
curl http://localhost:5002/api/orders
```

## 🏗️ Architecture

**ProductService** ↔️ **OrderService** via **Dapr** → **Redis**

- **ProductService**: RESTful API for product catalog (CRUD, inventory)
- **OrderService**: Order processing with product integration  
- **Dapr Runtime**: Service mesh (communication, state, pub/sub)
- **Redis**: State store and message broker

## 📁 Project Structure

```
├── src/                    # Microservices (.NET 8)
│   ├── ProductService/     # Product management API
│   ├── OrderService/       # Order processing API  
│   └── Shared/            # Common models & DTOs
├── deploy/                # Infrastructure & deployment
│   ├── templates/         # Bicep templates for Azure
│   └── scripts/          # Automation scripts
├── docs/                 # Comprehensive documentation
└── scripts/              # Development automation
```

## 🛠️ Technology Stack

- **.NET 8** - Latest LTS with performance improvements
- **Dapr v1.15** - Service mesh for microservices  
- **Redis 7** - State store and pub/sub broker
- **Azure Container Apps** - Serverless Kubernetes platform
- **Podman** - Secure, rootless containers

## 📖 Documentation

- **[Architecture](./docs/ARCHITECTURE.md)** - Detailed technical architecture
- **[Deployment](./docs/DEPLOYMENT.md)** - Complete deployment guide  
- **[Development](./docs/DEVELOPMENT.md)** - Local development setup
- **[Troubleshooting](./docs/TROUBLESHOOTING.md)** - Common issues & solutions
- **[API Reference](./docs/API_REFERENCE.md)** - API documentation

## 🧪 Testing

```bash
# Run all tests
dotnet test

# Test APIs
curl -X POST http://localhost:5001/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","price":99.99,"stock":100}'

curl -X POST http://localhost:5002/api/orders \
  -H "Content-Type: application/json" \  
  -d '{"productId":"<id>","customerName":"John","quantity":2}'
```

## ☁️ Azure Deployment

```bash
# Quick deploy to Azure Container Apps
./deploy/scripts/deploy.sh \
  --resource-group myapp-rg \
  --location eastus2

# Or use deployment guide
# See: docs/DEPLOYMENT.md
```

## 🎯 Key Features

✅ **Production Ready** - Security, monitoring, health checks  
✅ **Cloud Native** - Dapr service mesh, containerized  
✅ **Scalable** - Horizontal scaling, load balancing  
✅ **Observable** - Structured logging, distributed tracing  
✅ **Testable** - Unit tests, integration tests, API tests  

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/name`)  
3. Commit changes (`git commit -m 'Add feature'`)
4. Push branch (`git push origin feature/name`)
5. Open Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

**Built with ❤️ using .NET 8, Dapr, and Azure Container Apps**