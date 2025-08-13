# Azure Deployment Guide - Dapr Microservices

This guide walks you through deploying the Dapr microservices solution to Azure Container Apps.

## 🚀 Quick Deploy (Recommended)

### Prerequisites
```bash
# Install required tools
az --version    # Azure CLI 2.60+
podman --version # Podman 5.0+
```

### One-Command Deployment
```bash
# Deploy everything to Azure
./deploy-to-azure.sh --resource-group my-microservices-rg
```

This single command will:
✅ Create resource group  
✅ Deploy infrastructure (Container Apps, Redis, Registry)  
✅ Build and push container images  
✅ Deploy applications  
✅ Provide service URLs for testing

## 📋 What Gets Deployed

### Azure Resources Created

| Resource Type | Name | Purpose |
|---------------|------|---------|
| **Container Apps Environment** | `daprmicro-env` | Managed Dapr runtime environment |
| **Container Registry** | `daprmicroregistry` | Private container image registry |
| **Redis Cache** | `daprmicroredis` | State store and pub/sub broker |
| **Log Analytics** | `daprmicrologs` | Centralized logging |
| **Application Insights** | `daprmicroinsights` | Application monitoring |
| **ProductService** | `daprmicro-productservice` | Product catalog API |
| **OrderService** | `daprmicro-orderservice` | Order processing API |

### Cost Estimate
- **Container Apps**: ~$30-50/month (Basic tier)
- **Redis**: ~$15-20/month (Basic C0)
- **Log Analytics**: ~$5-10/month
- **Container Registry**: ~$5/month (Basic)
- **Total**: ~$55-85/month

## 🛠️ Manual Deployment Steps

If you prefer step-by-step deployment:

### 1. Login to Azure
```bash
az login
az account set --subscription "your-subscription-id"
```

### 2. Create Resource Group
```bash
az group create --name my-microservices-rg --location eastus2
```

### 3. Deploy Infrastructure
```bash
az deployment group create \
    --resource-group my-microservices-rg \
    --template-file infrastructure/azure/main.bicep \
    --parameters @infrastructure/azure/main.bicepparam
```

### 4. Build and Push Images
```bash
# Login to your container registry
az acr login --name daprmicroregistry

# Build and push images
./scripts/build-images.sh \
    --registry daprmicroregistry.azurecr.io \
    --tag latest \
    --push
```

### 5. Update Applications with Images
```bash
az deployment group create \
    --resource-group my-microservices-rg \
    --template-file infrastructure/azure/main.bicep \
    --parameters \
        productServiceImage=daprmicroregistry.azurecr.io/productservice:latest \
        orderServiceImage=daprmicroregistry.azurecr.io/orderservice:latest
```

## 🔧 Customization Options

### Change Region
```bash
./deploy-to-azure.sh \
    --resource-group my-rg \
    --location westus2
```

### Custom Naming
```bash
./deploy-to-azure.sh \
    --resource-group my-rg \
    --prefix mycompany
```

### Environment-Specific Deployments
```bash
# Development
./deploy-to-azure.sh -g myapp-dev-rg -p myappdev

# Staging
./deploy-to-azure.sh -g myapp-staging-rg -p myappstg

# Production  
./deploy-to-azure.sh -g myapp-prod-rg -p myappprod
```

## 🧪 Testing Your Deployment

### Health Checks
```bash
# Check if services are healthy
curl https://your-productservice-url/health
curl https://your-orderservice-url/health
```

### API Testing
```bash
# Get all products
curl https://your-productservice-url/api/products

# Create a product
curl -X POST https://your-productservice-url/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "description": "A test product",
    "price": 99.99,
    "stock": 100
  }'

# Create an order
curl -X POST https://your-orderservice-url/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "productId": "product-id-from-above",
    "customerName": "John Doe",
    "customerEmail": "john@example.com",
    "quantity": 2
  }'
```

## 📊 Monitoring and Troubleshooting

### View Logs
```bash
# ProductService logs
az containerapp logs show \
    --name daprmicro-productservice \
    --resource-group my-microservices-rg \
    --follow

# OrderService logs
az containerapp logs show \
    --name daprmicro-orderservice \
    --resource-group my-microservices-rg \
    --follow
```

### Application Insights
1. Go to Azure Portal
2. Navigate to your Application Insights resource
3. View metrics, logs, and distributed traces

### Redis Insights
```bash
# Connect to Redis for debugging
az redis show-access-keys --name daprmicroredis --resource-group my-microservices-rg
# Use Redis CLI or Redis Insight tool
```

## 🔄 Updates and CI/CD

### Manual Updates
```bash
# Rebuild and redeploy
./scripts/build-images.sh --registry your-registry.azurecr.io --tag v1.1.0 --push

# Update container apps
az containerapp update \
    --name daprmicro-productservice \
    --resource-group my-microservices-rg \
    --image your-registry.azurecr.io/productservice:v1.1.0
```

### GitHub Actions Integration
The solution includes:
- `.github/workflows/deploy.yml` for automated deployments
- Service principal authentication
- Environment-specific deployments

## 🔒 Security Best Practices

### Network Security
- Container Apps use internal networking by default
- Redis requires authentication
- Container Registry uses admin credentials (consider service principals for production)

### Secrets Management
```bash
# Use Azure Key Vault for production secrets
az keyvault create --name my-microservices-kv --resource-group my-microservices-rg
```

### Monitoring
- Enable Application Insights for all services
- Set up alerts for critical metrics
- Use Log Analytics for centralized logging

## 🧹 Cleanup

### Delete Everything
```bash
# Remove the entire resource group
az group delete --name my-microservices-rg --yes --no-wait
```

### Selective Cleanup
```bash
# Remove just the container apps
az containerapp delete --name daprmicro-productservice --resource-group my-microservices-rg
az containerapp delete --name daprmicro-orderservice --resource-group my-microservices-rg
```

## 🆘 Troubleshooting

### Common Issues

**Build Failures**
```bash
# Check Podman status
podman system info

# Verify Dockerfiles exist
ls -la infrastructure/docker/
```

**Registry Login Issues**
```bash
# Re-login to ACR
az acr login --name your-registry

# Check credentials
az acr credential show --name your-registry
```

**Container Apps Not Starting**
```bash
# Check logs for startup issues
az containerapp logs show --name your-app --resource-group your-rg

# Verify image exists
az acr repository show --name your-registry --repository productservice
```

**Dapr Communication Issues**
```bash
# Check Dapr components
az containerapp env dapr-component list --name daprmicro-env --resource-group your-rg

# Verify Redis connectivity
az redis show --name daprmicroredis --resource-group your-rg
```

## 🎯 Next Steps

After successful deployment:

1. **Set up monitoring** - Configure Application Insights dashboards
2. **Implement CI/CD** - Set up GitHub Actions or Azure DevOps
3. **Security hardening** - Implement Azure Key Vault and managed identities
4. **Custom domains** - Configure custom DNS and SSL certificates
5. **Scaling policies** - Tune auto-scaling rules based on load patterns

---

**🎉 Congratulations!** Your microservices are now running in Azure Container Apps with Dapr service mesh!