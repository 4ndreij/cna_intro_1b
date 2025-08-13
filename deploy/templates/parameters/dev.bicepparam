using '../main.bicep'

// Environment-specific parameters for Development
param environmentName = 'daprmicro-dev-env'
param namePrefix = 'daprmicrodev'
param environmentType = 'dev'
param location = 'eastus2'

// Container images - will be populated during deployment
param productServiceImage = '${namePrefix}registry.azurecr.io/productservice:latest'
param orderServiceImage = '${namePrefix}registry.azurecr.io/orderservice:latest'

// Registry configuration
param registryAdminUserEnabled = true