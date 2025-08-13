using '../main.bicep'

// Environment-specific parameters for Production
param environmentName = 'daprmicro-prod-env'
param namePrefix = 'daprmicroprod'
param environmentType = 'production'
param location = 'eastus2'

// Container images - will be populated during deployment
param productServiceImage = '${namePrefix}registry.azurecr.io/productservice:latest'
param orderServiceImage = '${namePrefix}registry.azurecr.io/orderservice:latest'

// Registry configuration
param registryAdminUserEnabled = false  // More secure for production