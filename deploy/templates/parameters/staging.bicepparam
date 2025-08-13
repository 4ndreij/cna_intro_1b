using '../main.bicep'

// Environment-specific parameters for Staging
param environmentName = 'daprmicro-staging-env'
param namePrefix = 'daprmicrostaging'
param environmentType = 'staging'
param location = 'eastus2'

// Container images - will be populated during deployment
param productServiceImage = '${namePrefix}registry.azurecr.io/productservice:latest'
param orderServiceImage = '${namePrefix}registry.azurecr.io/orderservice:latest'

// Registry configuration
param registryAdminUserEnabled = true