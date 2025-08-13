@description('The name of the container apps environment')
param environmentName string = 'dapr-microservices-env'

@description('The location of the resources')
param location string = resourceGroup().location

@description('The name prefix for resources')
param namePrefix string = 'daprmicro'

@description('The container registry name')
param containerRegistryName string = '${namePrefix}registry'

@description('Log Analytics workspace name')
param logAnalyticsName string = '${namePrefix}logs'

@description('Application Insights name')
param appInsightsName string = '${namePrefix}insights'

@description('Product Service container image')
param productServiceImage string = 'productservice:latest'

@description('Order Service container image')  
param orderServiceImage string = 'orderservice:latest'

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
  }
}

// Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    daprAIInstrumentationKey: appInsights.properties.InstrumentationKey
    daprAIConnectionString: appInsights.properties.ConnectionString
  }
}

// Dapr Components - Redis PubSub
resource daprPubSub 'Microsoft.App/managedEnvironments/daprComponents@2023-05-01' = {
  name: 'product-pubsub'
  parent: containerAppsEnvironment
  properties: {
    componentType: 'pubsub.redis'
    version: 'v1'
    metadata: [
      {
        name: 'redisHost'
        value: '${redis.name}.redis.cache.windows.net:6380'
      }
      {
        name: 'redisPassword'
        secretRef: 'redis-password'
      }
      {
        name: 'enableTLS'
        value: 'true'
      }
    ]
    secrets: [
      {
        name: 'redis-password'
        value: redis.listKeys().primaryKey
      }
    ]
    scopes: [
      'productservice'
      'orderservice'
    ]
  }
}

// Dapr Components - Redis StateStore
resource daprStateStore 'Microsoft.App/managedEnvironments/daprComponents@2023-05-01' = {
  name: 'statestore'
  parent: containerAppsEnvironment
  properties: {
    componentType: 'state.redis'
    version: 'v1'
    metadata: [
      {
        name: 'redisHost'
        value: '${redis.name}.redis.cache.windows.net:6380'
      }
      {
        name: 'redisPassword'
        secretRef: 'redis-password'
      }
      {
        name: 'enableTLS'
        value: 'true'
      }
    ]
    secrets: [
      {
        name: 'redis-password'
        value: redis.listKeys().primaryKey
      }
    ]
    scopes: [
      'productservice'
      'orderservice'
    ]
  }
}

// Azure Cache for Redis
resource redis 'Microsoft.Cache/redis@2023-08-01' = {
  name: '${namePrefix}redis'
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

// Product Service Container App
resource productService 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${namePrefix}-productservice'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      dapr: {
        enabled: true
        appId: 'productservice'
        appProtocol: 'http'
        appPort: 8080
        logLevel: 'info'
        enableApiLogging: true
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.name
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'productservice'
          image: productServiceImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 30
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    daprPubSub
    daprStateStore
  ]
}

// Order Service Container App
resource orderService 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${namePrefix}-orderservice'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      dapr: {
        enabled: true
        appId: 'orderservice'
        appProtocol: 'http'
        appPort: 8080
        logLevel: 'info'
        enableApiLogging: true
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.name
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'orderservice'
          image: orderServiceImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'Services__ProductServiceUrl'
              value: 'http://productservice'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 30
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    productService
    daprPubSub
    daprStateStore
  ]
}

// Outputs
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output productServiceUrl string = productService.properties.configuration.ingress.fqdn
output orderServiceUrl string = orderService.properties.configuration.ingress.fqdn
output logAnalyticsWorkspaceId string = logAnalytics.id
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString
