# Troubleshooting Guide

Common issues and solutions when deploying the Dapr microservices solution to Azure Container Apps.

## 🚨 Common Issues

### 1. Azure CLI "Content Already Consumed" Error

**Symptoms:**
```bash
Error: The input content has already been consumed and cannot be read again.
```

**Cause:** Azure CLI streaming issue with certain commands.

**Solutions:**
```bash
# Add --output none to deployment commands
az deployment group create --template-file main.bicep --parameters dev.bicepparam --output none

# Or use alternative approaches
az deployment group create --template-file main.bicep --parameters @dev.json
```

**Prevention:** The deployment scripts handle this automatically with `--output none` flags.

---

### 2. Container App Startup Failures

**Symptoms:**
- Container apps stuck in "Provisioning" state
- Health checks failing
- Services not responding

**Diagnosis:**
```bash
# Check container app status
az containerapp show --name myapp-productservice --resource-group myapp-rg

# View logs for startup issues
az containerapp logs show --name myapp-productservice --resource-group myapp-rg --tail 50

# Check resource allocation
az containerapp show --name myapp-productservice --resource-group myapp-rg --query "properties.template.containers[0].resources"
```

**Common Causes & Solutions:**

#### Insufficient Resources
```bash
# Check current resource allocation
az containerapp revision list --name myapp-productservice --resource-group myapp-rg

# Update resources if needed
az containerapp update --name myapp-productservice --resource-group myapp-rg \
    --cpu 1.0 --memory 2Gi
```

#### Container Image Issues
```bash
# Verify image exists in registry
az acr repository list --name myregistry --output table
az acr repository show-tags --name myregistry --repository productservice

# Check container registry credentials
az acr credential show --name myregistry --resource-group myapp-rg
```

#### Port Configuration Problems
```bash
# Verify target port matches container port
az containerapp show --name myapp-productservice --resource-group myapp-rg \
    --query "properties.configuration.ingress.targetPort"
```

---

### 3. Dapr Sidecar Issues

**Symptoms:**
```
Error processing component: statestore
Failed to initialize Dapr runtime
```

**Diagnosis:**
```bash
# Check Dapr sidecar logs
az containerapp logs show --name myapp-productservice --resource-group myapp-rg --container daprd

# Verify Dapr components
az containerapp env dapr-component list --name myapp-env --resource-group myapp-rg
```

**Common Solutions:**

#### Redis Connection Issues
```bash
# Check Redis container status
az containerapp show --name myapp-redis --resource-group myapp-rg

# Verify Redis is accessible (should show TCP ingress)
az containerapp show --name myapp-redis --resource-group myapp-rg \
    --query "properties.configuration.ingress"

# Test Redis connectivity from another container
az containerapp exec --name myapp-productservice --resource-group myapp-rg \
    --command -- redis-cli -h myapp-redis -p 6379 ping
```

#### Component Configuration Issues
```bash
# Check component configuration
az containerapp env dapr-component show --name myapp-env --resource-group myapp-rg \
    --dapr-component-name statestore

# Recreate component if needed
az containerapp env dapr-component set --name myapp-env --resource-group myapp-rg \
    --dapr-component-name statestore --yaml statestore.yml
```

---

### 4. Service-to-Service Communication Failures

**Symptoms:**
```
HttpRequestException: Connection timeout
Service 'productservice' not found
```

**Diagnosis:**
```bash
# Check service URLs and accessibility
az containerapp show --name myapp-productservice --resource-group myapp-rg \
    --query "properties.configuration.ingress.fqdn"

# Verify Dapr service discovery
az containerapp logs show --name myapp-orderservice --resource-group myapp-rg --container daprd
```

**Solutions:**

#### Using Dapr Service Invocation (Recommended)
```csharp
// In OrderService, use Dapr service invocation instead of direct HTTP
await daprClient.InvokeMethodAsync<Product>("productservice", "api/products/1");
```

#### Direct HTTP (Not Recommended)
```bash
# Note: Using Dapr service invocation is preferred, but if direct HTTP is needed:
az containerapp update --name myapp-orderservice --resource-group myapp-rg \
    --set-env-vars "Services__ProductServiceUrl=http://productservice"
```

---

### 5. Container Registry Authentication Failures

**Symptoms:**
```
Failed to pull image: authentication required
Error: failed to resolve image
```

**Diagnosis:**
```bash
# Check registry credentials
az acr credential show --name myregistry

# Verify container app has correct registry configuration
az containerapp show --name myapp-productservice --resource-group myapp-rg \
    --query "properties.configuration.registries"
```

**Solutions:**

#### Registry Admin User Disabled
```bash
# Enable admin user if needed
az acr update --name myregistry --admin-enabled true

# Or use managed identity (recommended for production)
az containerapp update --name myapp-productservice --resource-group myapp-rg \
    --registry-identity system
```

#### Wrong Registry URL
```bash
# Check registry login server
az acr show --name myregistry --query loginServer

# Update container image URLs if needed
az containerapp update --name myapp-productservice --resource-group myapp-rg \
    --image myregistry.azurecr.io/productservice:latest
```

---

### 6. Networking and DNS Issues

**Symptoms:**
```
Name resolution failed
Connection refused
Could not resolve hostname
```

**Diagnosis:**
```bash
# Check DNS resolution from container
az containerapp exec --name myapp-orderservice --resource-group myapp-rg \
    --command -- nslookup myapp-redis

# Verify network configuration
az containerapp env show --name myapp-env --resource-group myapp-rg
```

**Solutions:**

#### Internal Service Communication
```bash
# Use app name for internal communication (not FQDN)
# Correct: myapp-redis:6379
# Incorrect: myapp-redis.eastus2.azurecontainerapps.io:6379
```

#### Container Apps Environment Issues
```bash
# Check environment status
az containerapp env show --name myapp-env --resource-group myapp-rg --query "properties.provisioningState"

# Recreate environment if corrupted
az containerapp env delete --name myapp-env --resource-group myapp-rg
# Then redeploy using deployment scripts
```

---

### 7. Resource Quota and Limits

**Symptoms:**
```
QuotaExceeded: Subscription quota exceeded
InsufficientCapacity: Not enough capacity
```

**Diagnosis:**
```bash
# Check resource usage
az vm list-usage --location eastus2 --output table

# Check Container Apps limits
az resource list --resource-type "Microsoft.App/containerApps" --output table
```

**Solutions:**

#### Scale Down Resources
```bash
# Reduce replica counts
az containerapp update --name myapp-productservice --resource-group myapp-rg \
    --min-replicas 1 --max-replicas 3

# Use smaller resource allocations
az containerapp update --name myapp-productservice --resource-group myapp-rg \
    --cpu 0.25 --memory 0.5Gi
```

#### Request Quota Increase
```bash
# Check current quotas
az vm list-usage --location eastus2

# Submit quota increase request through Azure portal
```

---

### 8. Log Analytics and Monitoring Issues

**Symptoms:**
- No logs appearing in Azure Monitor
- Application Insights not collecting data
- Missing metrics

**Diagnosis:**
```bash
# Check Log Analytics workspace
az monitor log-analytics workspace show --workspace-name myapp-logs --resource-group myapp-rg

# Verify Application Insights configuration
az monitor app-insights component show --app myapp-insights --resource-group myapp-rg
```

**Solutions:**

#### Connection String Issues
```bash
# Get correct Application Insights connection string
CONNECTION_STRING=$(az monitor app-insights component show --app myapp-insights --resource-group myapp-rg --query connectionString --output tsv)

# Update container apps with correct connection string
az containerapp update --name myapp-productservice --resource-group myapp-rg \
    --set-env-vars "APPLICATIONINSIGHTS_CONNECTION_STRING=$CONNECTION_STRING"
```

#### Log Analytics Workspace Key Rotation
```bash
# Get new workspace keys
WORKSPACE_ID=$(az monitor log-analytics workspace show --workspace-name myapp-logs --resource-group myapp-rg --query customerId --output tsv)
WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys --workspace-name myapp-logs --resource-group myapp-rg --query primarySharedKey --output tsv)

# Update Container Apps Environment
az containerapp env update --name myapp-env --resource-group myapp-rg \
    --logs-workspace-id "$WORKSPACE_ID" --logs-workspace-key "$WORKSPACE_KEY"
```

---

## 🔧 Debugging Tools

### Container Logs
```bash
# Real-time logs
az containerapp logs show --name myapp-productservice --resource-group myapp-rg --follow

# Dapr sidecar logs
az containerapp logs show --name myapp-productservice --resource-group myapp-rg --container daprd --follow

# Historical logs (last 1 hour)
az containerapp logs show --name myapp-productservice --resource-group myapp-rg --since 1h
```

### Container Shell Access
```bash
# Execute commands in running container
az containerapp exec --name myapp-productservice --resource-group myapp-rg --command -- /bin/bash

# Test connectivity
az containerapp exec --name myapp-productservice --resource-group myapp-rg \
    --command -- curl -v http://myapp-redis:6379

# Check environment variables
az containerapp exec --name myapp-productservice --resource-group myapp-rg \
    --command -- printenv
```

### Health Checks
```bash
# Container app health
az containerapp show --name myapp-productservice --resource-group myapp-rg --query "properties.runningStatus"

# Application health endpoint
curl https://myapp-productservice.eastus2.azurecontainerapps.io/health

# Dapr health
curl https://myapp-productservice.eastus2.azurecontainerapps.io/v1.0/healthz
```

### Resource Monitoring
```bash
# CPU and memory usage
az monitor metrics list --resource /subscriptions/sub-id/resourceGroups/myapp-rg/providers/Microsoft.App/containerApps/myapp-productservice \
    --metric "CpuPercentage,MemoryPercentage"

# Request metrics  
az monitor metrics list --resource /subscriptions/sub-id/resourceGroups/myapp-rg/providers/Microsoft.App/containerApps/myapp-productservice \
    --metric "Requests,ResponseTime"
```

## 🎯 Quick Fixes

### Restart Services
```bash
# Restart by updating with no-op change
az containerapp update --name myapp-productservice --resource-group myapp-rg --tags restart=true

# Or create new revision
az containerapp revision copy --name myapp-productservice --resource-group myapp-rg
```

### Reset Dapr Components
```bash
# Remove and recreate state store
az containerapp env dapr-component remove --name myapp-env --resource-group myapp-rg --dapr-component-name statestore
az containerapp env dapr-component set --name myapp-env --resource-group myapp-rg --dapr-component-name statestore --yaml statestore.yml
```

### Clear Redis Data
```bash
# Connect to Redis and flush data
az containerapp exec --name myapp-redis --resource-group myapp-rg --command -- redis-cli flushall
```

## 🆘 Emergency Procedures

### Complete Service Reset
```bash
# Stop traffic to problematic service
az containerapp ingress disable --name myapp-productservice --resource-group myapp-rg

# Scale down to zero
az containerapp update --name myapp-productservice --resource-group myapp-rg --min-replicas 0 --max-replicas 0

# Investigate issue, then restore
az containerapp update --name myapp-productservice --resource-group myapp-rg --min-replicas 1 --max-replicas 3
az containerapp ingress enable --name myapp-productservice --resource-group myapp-rg --type External --target-port 8080
```

### Disaster Recovery
```bash
# Use cleanup script to remove all resources
./scripts/cleanup.sh --resource-group myapp-rg --prefix myapp --confirm

# Redeploy from scratch
./scripts/deploy.sh --resource-group myapp-rg --environment dev
```

## 📞 Getting Help

### Azure Support
```bash
# Create support ticket if needed
az support tickets create --ticket-name "Container Apps Issue" \
    --description "Detailed description of issue" \
    --severity minimal \
    --contact-country "US" \
    --contact-first-name "Your" \
    --contact-last-name "Name" \
    --contact-primary-contact-method "email" \
    --contact-email "your@email.com"
```

### Community Resources
- [Azure Container Apps GitHub](https://github.com/microsoft/azure-container-apps)
- [Dapr Discord](https://discord.com/invite/ptHhX6jc34)
- [Stack Overflow - azure-container-apps](https://stackoverflow.com/questions/tagged/azure-container-apps)

### Logging Support Information
```bash
# Gather diagnostic information for support
echo "=== Container Apps Environment ===" > diagnostic.txt
az containerapp env show --name myapp-env --resource-group myapp-rg >> diagnostic.txt

echo "=== Container Apps ===" >> diagnostic.txt
az containerapp list --resource-group myapp-rg --output table >> diagnostic.txt

echo "=== Recent Logs ===" >> diagnostic.txt
az containerapp logs show --name myapp-productservice --resource-group myapp-rg --tail 100 >> diagnostic.txt
```

---

## 📚 Additional Resources

- [Azure Container Apps Troubleshooting](https://docs.microsoft.com/en-us/azure/container-apps/troubleshooting)
- [Dapr Troubleshooting](https://docs.dapr.io/operations/troubleshooting/)
- [Container Registry Troubleshooting](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-troubleshoot-login)