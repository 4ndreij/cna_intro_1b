# Azure Container Apps Deployment Guide

Complete guide for deploying the Dapr microservices solution to Azure Container Apps.

## 📋 Prerequisites

### Required Tools
- **Azure CLI** 2.60+ - [Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Podman** 5.0+ - [Install Guide](https://podman.io/getting-started/installation)
- **Bicep CLI** - Installed with Azure CLI 2.20+
- **bash** shell (Linux, macOS, WSL2)

### Azure Setup
```bash
# Login to Azure
az login

# Set subscription (if you have multiple)
az account set --subscription "Your Subscription Name"

# Register required providers (one-time setup)
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.OperationalInsights
```

## 🚀 Quick Deployment

### Option 1: Using Deployment Scripts (Recommended)

```bash
# Clone the repository
cd /path/to/your/project

# Navigate to deployment folder
cd deploy

# Configure deployment (edit the configuration file)
cp config/deployment.yml.example config/deployment.yml
# Edit config/deployment.yml with your settings

# Deploy everything with one command
./scripts/deploy.sh --resource-group myapp-dev-rg --environment dev

# Validate the deployment
./scripts/validate.sh --resource-group myapp-dev-rg --prefix daprmicrodev
```

### Option 2: Using Bicep Templates

```bash
# Create resource group
az group create --name myapp-dev-rg --location eastus2

# Deploy infrastructure using Bicep
az deployment group create \
    --resource-group myapp-dev-rg \
    --template-file templates/main.bicep \
    --parameters templates/parameters/dev.bicepparam

# Build and push containers manually
./scripts/build-and-push.sh myapp-dev-rg daprmicrodevregistry
```

## 📁 Project Structure

```
deploy/
├── config/
│   ├── deployment.yml           # Main configuration file
│   ├── dapr-components/         # Dapr component templates
│   │   ├── statestore.yml      # Redis state store configuration
│   │   └── pubsub.yml          # Redis pub/sub configuration
│   └── parameters/             # Environment-specific parameters
├── scripts/
│   ├── deploy.sh               # Main deployment script
│   ├── build-and-push.sh       # Container build and push
│   ├── infrastructure.sh       # Infrastructure setup
│   ├── cleanup.sh              # Resource cleanup
│   └── validate.sh             # Deployment validation
├── templates/
│   ├── main.bicep              # Main Bicep template
│   └── parameters/             # Parameter files per environment
│       ├── dev.bicepparam
│       ├── staging.bicepparam
│       └── production.bicepparam
└── docs/                       # Documentation
```

## ⚙️ Configuration

### Main Configuration File

Edit `config/deployment.yml` to customize your deployment:

```yaml
# Azure Configuration
azure:
  subscription_id: ""          # Optional, uses current if empty
  location: "eastus2"         # Azure region

# Naming Configuration  
naming:
  prefix: "daprmicro"         # Resource name prefix
  environment: "dev"          # dev, staging, production

# Container Apps Configuration
containerApps:
  environment:
    name: "${naming.prefix}-${naming.environment}-env"
    dapr:
      version: "1.15"
      
  applications:
    productService:
      name: "${naming.prefix}-productservice"
      replicas:
        min: 1
        max: 3
      resources:
        cpu: "0.5"
        memory: "1Gi"
```

### Environment-Specific Configurations

Each environment (dev, staging, production) has its own parameter file in `templates/parameters/`:

- **Development**: Minimal resources, detailed logging
- **Staging**: Medium resources, balanced configuration
- **Production**: High availability, optimized for performance and cost

## 🔧 Deployment Options

### Full Deployment (Recommended for first-time)

```bash
./scripts/deploy.sh --resource-group myapp-dev-rg --environment dev
```

This performs:
1. ✅ Infrastructure setup (Registry, Log Analytics, Container Apps Environment)
2. ✅ Container build and push
3. ✅ Redis container deployment
4. ✅ Dapr components configuration
5. ✅ Microservices deployment

### Selective Deployment

Skip certain steps if already completed:

```bash
# Skip infrastructure deployment
./scripts/deploy.sh --resource-group myapp-dev-rg --skip-infrastructure

# Skip container build (if images already exist)
./scripts/deploy.sh --resource-group myapp-dev-rg --skip-build

# Dry run (see what would be deployed)
./scripts/deploy.sh --resource-group myapp-dev-rg --dry-run
```

### Manual Step-by-Step Deployment

```bash
# 1. Create infrastructure
./scripts/infrastructure.sh myapp-dev-rg eastus2 daprmicrodev daprmicrodev-env

# 2. Build and push containers
./scripts/build-and-push.sh myapp-dev-rg daprmicrodevregistry

# 3. Deploy applications (use main deploy script or manual commands)
```

## 🏗️ What Gets Deployed

### Azure Resources

| Resource Type | Name Pattern | Purpose |
|--------------|--------------|---------|
| Resource Group | User-specified | Contains all resources |
| Container Registry | `{prefix}registry` | Private container images |
| Log Analytics | `{prefix}-logs` | Centralized logging |
| Application Insights | `{prefix}-insights` | APM and monitoring |
| Container Apps Environment | `{prefix}-env` | Container Apps runtime |
| Container App (Redis) | `{prefix}-redis` | Redis state store & pub/sub |
| Container App (ProductService) | `{prefix}-productservice` | Product catalog API |
| Container App (OrderService) | `{prefix}-orderservice` | Order processing API |

### Dapr Components

| Component | Type | Purpose | Configuration |
|-----------|------|---------|---------------|
| `statestore` | state.redis | Persistent state | Redis containerized |
| `product-pubsub` | pubsub.redis | Async messaging | Redis containerized |

### Network Configuration

- **ProductService**: External ingress (public HTTPS)
- **OrderService**: External ingress (public HTTPS)  
- **Redis**: Internal ingress (TCP, container-to-container only)
- **Service-to-service communication**: Via Dapr service invocation

## 🔍 Validation & Testing

### Automated Validation

```bash
# Run full validation suite
./scripts/validate.sh --resource-group myapp-dev-rg --prefix daprmicrodev

# Custom timeout for health checks
./scripts/validate.sh --resource-group myapp-dev-rg --prefix daprmicrodev --timeout 600
```

### Manual Testing

After successful deployment, test the APIs:

```bash
# Get service URLs (from deployment output)
PRODUCT_URL="https://daprmicrodev-productservice.eastus2.azurecontainerapps.io"
ORDER_URL="https://daprmicrodev-orderservice.eastus2.azurecontainerapps.io"

# Health checks
curl $PRODUCT_URL/health
curl $ORDER_URL/health

# Get products
curl $PRODUCT_URL/api/products

# Get orders
curl $ORDER_URL/api/orders

# Create an order (tests service-to-service communication via Dapr)
curl -X POST $ORDER_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 1, "quantity": 2}'
```

### Monitoring

```bash
# View real-time logs
az containerapp logs show --name daprmicrodev-productservice --resource-group myapp-dev-rg --follow

# View Dapr sidecar logs
az containerapp logs show --name daprmicrodev-productservice --resource-group myapp-dev-rg --container daprd --follow
```

## 🌍 Multi-Environment Deployment

### Development Environment
```bash
./scripts/deploy.sh --resource-group myapp-dev-rg --environment dev
```

### Staging Environment
```bash
./scripts/deploy.sh --resource-group myapp-staging-rg --environment staging
```

### Production Environment
```bash
./scripts/deploy.sh --resource-group myapp-prod-rg --environment production
```

Each environment gets:
- Separate resource groups and naming
- Environment-appropriate resource sizing
- Different logging levels and retention policies
- Tailored security configurations

## 🔧 Customization

### Adding New Microservices

1. **Update Bicep template** (`templates/main.bicep`):
   ```bicep
   resource newService 'Microsoft.App/containerApps@2023-05-01' = {
     name: '${namePrefix}-newservice'
     // ... configuration
   }
   ```

2. **Update build script** (`scripts/build-and-push.sh`):
   ```bash
   # Add new service build steps
   ```

3. **Update validation script** (`scripts/validate.sh`):
   ```bash
   # Add new service health checks
   ```

### Customizing Resource Sizes

Edit environment-specific parameter files in `templates/parameters/`:

```bicep
// production.bicepparam
param appMinReplicas = 3
param appMaxReplicas = 50
param appCpu = json('2.0')
param appMemory = '4Gi'
```

### Adding Custom Dapr Components

1. Create component YAML in `config/dapr-components/`
2. Update deployment script to configure component
3. Reference component in microservices code

## 🗑️ Cleanup

### Remove All Resources

```bash
# Safe cleanup with confirmation
./scripts/cleanup.sh --resource-group myapp-dev-rg --prefix daprmicrodev --confirm

# Dry run to see what would be deleted
./scripts/cleanup.sh --resource-group myapp-dev-rg --prefix daprmicrodev --dry-run
```

### Delete Entire Resource Group

```bash
# Nuclear option - deletes everything
az group delete --name myapp-dev-rg --yes --no-wait
```

## 🔐 Security Considerations

- Container registry uses private images with authentication
- Services communicate via Dapr (encrypted service-to-service)
- HTTPS-only external communication
- Non-root containers
- Secrets managed through Container Apps secrets
- Network isolation between internal and external services

## 🚨 Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Dapr Documentation](https://docs.dapr.io/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Project Architecture](ARCHITECTURE.md)