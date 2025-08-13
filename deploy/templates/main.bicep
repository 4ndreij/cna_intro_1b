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

@description('Redis container app name')
param redisAppName string = '${namePrefix}-redis'

@description('Product Service container app name')
param productServiceAppName string = '${namePrefix}-productservice'

@description('Order Service container app name')  
param orderServiceAppName string = '${namePrefix}-orderservice'

@description('Product Service container image')
param productServiceImage string

@description('Order Service container image')  
param orderServiceImage string

@description('Redis container image')
param redisImage string = 'redis:7-alpine'

@description('Environment type (dev, staging, production)')
@allowed([
  'dev'
  'staging'
  'production'
])
param environmentType string = 'dev'

@description('Enable container registry admin user')
param registryAdminUserEnabled bool = true

// Variables for resource configuration based on environment
var isProd = environmentType == 'production'
var isStaging = environmentType == 'staging'

var logRetentionDays = isProd ? 90 : (isStaging ? 60 : 30)
var logDailyQuota = isProd ? 5 : (isStaging ? 3 : 1)

var appMinReplicas = isProd ? 2 : 1
var appMaxReplicas = isProd ? 20 : (isStaging ? 10 : 5)
var appCpu = isProd ? json('1.0') : json('0.5')
var appMemory = isProd ? '2Gi' : '1Gi'

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
    workspaceCapping: {
      dailyQuotaGb: logDailyQuota
    }
  }
  tags: {
    Environment: environmentType
    Application: 'DaprMicroservices'
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
  tags: {
    Environment: environmentType
    Application: 'DaprMicroservices'
  }
}

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: isProd ? 'Standard' : 'Basic'
  }
  properties: {
    adminUserEnabled: registryAdminUserEnabled
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: isProd ? 30 : 7
        status: isProd ? 'enabled' : 'disabled'
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
  tags: {
    Environment: environmentType
    Application: 'DaprMicroservices'
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
  tags: {
    Environment: environmentType
    Application: 'DaprMicroservices'
  }
}

// Redis Container App (containerized instead of managed service)
resource redisApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: redisAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 6379
        allowInsecure: true
        transport: 'tcp'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: 'redis'
          image: redisImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          args: [
            'redis-server'
            '--save'
            '60'
            '1'
            '--loglevel'
            'warning'
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  tags: {
    Environment: environmentType
    Application: 'DaprMicroservices'
    Component: 'Redis'
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
        value: '${redisAppName}:6379'
      }
    ]
    scopes: [
      'productservice'
      'orderservice'
    ]
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
        value: '${redisAppName}:6379'
      }
    ]
    scopes: [
      'productservice'
      'orderservice'
    ]
  }
}

// Product Service Container App
resource productService 'Microsoft.App/containerApps@2023-05-01' = {
  name: productServiceAppName
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
        logLevel: isProd ? 'warn' : 'info'
        enableApiLogging: !isProd
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
            cpu: appCpu
            memory: appMemory
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
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: appMinReplicas
        maxReplicas: appMaxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: isProd ? '100' : '50'
              }
            }
          }
        ]
      }
    }
  }
  tags: {
    Environment: environmentType
    Application: 'DaprMicroservices'
    Service: 'ProductService'
  }
  dependsOn: [
    redisApp
    daprPubSub
    daprStateStore
  ]
}

// Order Service Container App
resource orderService 'Microsoft.App/containerApps@2023-05-01' = {
  name: orderServiceAppName
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
        logLevel: isProd ? 'warn' : 'info'
        enableApiLogging: !isProd
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
            cpu: appCpu
            memory: appMemory
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
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: appMinReplicas
        maxReplicas: appMaxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: isProd ? '100' : '50'
              }
            }
          }
        ]
      }
    }
  }
  tags: {
    Environment: environmentType
    Application: 'DaprMicroservices'
    Service: 'OrderService'
  }
  dependsOn: [
    productService
    redisApp
    daprPubSub
    daprStateStore
  ]
}

// Outputs
@description('Container Apps Environment resource ID')
output containerAppsEnvironmentId string = containerAppsEnvironment.id

@description('Container Apps Environment name')
output containerAppsEnvironmentName string = containerAppsEnvironment.name

@description('Container Registry name')
output containerRegistryName string = containerRegistry.name

@description('Container Registry login server')
output containerRegistryLoginServer string = containerRegistry.properties.loginServer

@description('Product Service URL')
output productServiceUrl string = 'https://${productService.properties.configuration.ingress.fqdn}'

@description('Order Service URL')
output orderServiceUrl string = 'https://${orderService.properties.configuration.ingress.fqdn}'

@description('Log Analytics workspace resource ID')
output logAnalyticsWorkspaceId string = logAnalytics.id

@description('Application Insights connection string')
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Redis app name')
output redisAppName string = redisApp.name