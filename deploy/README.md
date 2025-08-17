# Deployment Quick Start

Quick reference for deploying the cloud-native microservices solution to Azure Container Apps.

## 🚀 Quick Deploy

```bash
# Deploy main application to Azure Container Apps  
./scripts/deploy.sh \
  --resource-group myapp-rg \
  --location eastus2

# Deploy AI observability (optional)
cd logic-app-observability-mvp
./deploy.sh \
  --resource-group myapp-rg \
  --app-insights-id "/subscriptions/.../components/myapp-insights" \
  --notification-email admin@company.com
```

## 📋 Prerequisites

- Azure CLI 2.60+
- Podman 5.0+
- Bicep CLI (latest)
- bash shell

## 🌍 Environment Support

- **Development**: For local development testing
- **Staging**: Pre-production environment
- **Production**: Production deployment

## 📖 Complete Documentation

For detailed instructions, see:
- **[Deployment Guide](../docs/DEPLOYMENT.md)** - Complete deployment procedures
- **[Architecture](../docs/ARCHITECTURE.md)** - Technical architecture details  
- **[Troubleshooting](../docs/TROUBLESHOOTING.md)** - Common deployment issues

## 🏗️ What Gets Deployed

### Azure Resources
- Container Apps Environment with Dapr
- Azure Container Registry (private)
- Redis Container (instead of managed service)
- Log Analytics Workspace
- Application Insights
- Networking and security configurations

### Applications
- **ProductService**: Product catalog microservice
- **OrderService**: Order processing microservice
- **Redis**: Containerized Redis for state store and pub/sub

### Dapr Components
- State store (Redis-based)
- Pub/Sub messaging (Redis-based)
- Service-to-service invocation
- Observability integration

## 🔒 Security Features

- Non-root containers
- Private container registry
- HTTPS-only communication
- Network isolation
- Secrets management

## 📊 Monitoring & Observability

- Application Insights integration
- Structured logging with Serilog
- Health checks and probes
- Dapr metrics and tracing

---

**Built with ❤️ for Azure Container Apps**