# Azure Container Apps Deployment Guide

This folder contains all the necessary scripts, templates, and configurations for deploying the Dapr microservices solution to Azure Container Apps.

## 📁 Folder Structure

```
deploy/
├── README.md                    # This file
├── config/                      # Configuration files
│   ├── deployment.yml           # Deployment configuration
│   ├── dapr-components/        # Dapr component configurations
│   └── parameters/             # Environment-specific parameters
├── scripts/                     # Deployment scripts
│   ├── deploy.sh               # Main deployment script
│   ├── build-and-push.sh       # Container build and push
│   ├── infrastructure.sh       # Infrastructure setup
│   ├── cleanup.sh              # Resource cleanup
│   └── validate.sh             # Post-deployment validation
├── templates/                   # Bicep templates
│   ├── main.bicep              # Main infrastructure template
│   ├── container-apps.bicep    # Container Apps specific resources
│   └── parameters/             # Parameter files per environment
└── docs/                       # Documentation
    ├── DEPLOYMENT.md           # Detailed deployment instructions
    ├── TROUBLESHOOTING.md      # Common issues and solutions
    └── ARCHITECTURE.md         # Solution architecture overview
```

## 🚀 Quick Deploy

```bash
# 1. Configure deployment
cp config/deployment.yml.example config/deployment.yml
# Edit config/deployment.yml with your settings

# 2. Deploy everything
./scripts/deploy.sh --env production --resource-group my-microservices-rg

# 3. Validate deployment
./scripts/validate.sh --env production
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

## 📚 Documentation

See `/deploy/docs/` for detailed guides:
- [Deployment Instructions](docs/DEPLOYMENT.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [Architecture Overview](docs/ARCHITECTURE.md)

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